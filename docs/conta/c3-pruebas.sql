-- =====================================================================
-- C3 · Las pruebas de los puentes — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, después de c1, c2-libro.sql y
-- c3-puentes.sql. Lo que enseña al final es la tabla de resultados: una
-- fila por prueba, con lo esperado, lo obtenido y ok. Todo en true = los
-- puentes aguantan y la app de obra sigue igual.
--
-- NO DEJA RASTRO. Cada prueba es un bloque «do» con una subtransacción
-- adentro: arma lo que necesita (una tarjeta, un proveedor, reglas y
-- papeles de prueba, con ids negativos y nombres «c3-pruebas»), suplanta
-- al usuario cuando la prueba es de un rol (request.jwt.claims + set local
-- role), ataca o usa, y al final lanza MXT00 para DESHACER todo lo escrito:
-- los papeles, sus asientos, los números, las reglas, los cierres. El
-- resultado viaja en variables, que no se deshacen, y se apunta en
-- _pruebas, que es temporal y muere con la sesión. Los papeles de prueba
-- entran con su id escrito («overriding system value»), así que tampoco
-- avanzan las secuencias de recibos, facturas ni horas. La última prueba
-- compara la foto del final con la del principio. (Lo único que puede
-- moverse fuera de estas tablas: si en producción los avisos de horas
-- llaman a pg_net, su cola interna gasta un número; la petición se deshace
-- con todo lo demás y no sale ningún aviso.)
--
-- CANDADOS BREVES: la prueba 39 apaga un instante el puente de recibos, y
-- la 82 la guarda de puente_cuentas (alter table, con lock_timeout de 2 s:
-- si la app está usando la tabla, sale «omitida» en vez de hacerla
-- esperar), las que cierran meses toman periodos en exclusiva, la 69 le
-- devuelve un instante la escritura a la vista recibos_equipo (grant) para
-- ver que la guarda del recibo la para igual, y la 90 le da al dueño un
-- instante un update en Storage (una policy) para ver que el papel no se
-- mueve igual. Todo dura milisegundos y se deshace con la prueba.
--
-- LOS PUENTES SON DIFERIDOS: corren al confirmar la transacción. Una
-- prueba que nunca confirma los pone en «immediate» (set constraints
-- trg_puente_…_despues immediate) para verlos correr al terminar cada
-- sentencia, como si confirmara. Y las que prueban lo que pasa AL
-- CONFIRMAR ponen al final todo en immediate (set constraints all
-- immediate): así corren también los controles diferidos del libro.
--
-- EL RELOJ FINGIDO Y EL CANDADO DE PERIODOS: los de c2-pruebas.sql, con
-- sus mismas reglas (ver su cabecera). La prueba que cierra meses toma
-- antes, como primera sentencia de su subtransacción, «lock table
-- public.periodos in exclusive mode».
--
-- Rojo primero, SOLO en el banco de pruebas (pruebas/conta/correr.sh con
-- «c3-puentes.sql:A»): con solo el bloque A (tablas, reglas, funciones
-- mínimas, sin triggers ni puentes), estas pruebas fallan porque los
-- puentes no postean y los ataques entran, no porque falte una tabla.
-- Pasan igual en rojo las de regresión que no dependen de los puentes (la
-- corrección de horas, el trigger de materiales) y la de no dejar rastro.
--
-- Los datos se buscan, no se inventan: el dueño, uno del equipo (si no
-- hay, esas pruebas salen «omitidas»), una obra, el mes abierto más
-- antiguo desde el corte y las cuentas de puente_cuentas.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- ---------------------------------------------------------------------
-- Antes de nada: lo que estas pruebas dan por hecho. Pegadas antes que
-- c3-puentes.sql, paran aquí con un mensaje en español.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.puente_documentos') is null or to_regclass('public.cobros') is null
     or to_regprocedure('public.fn_puentes_correr(date)') is null
     or to_regprocedure('public.fn_postear_interno(jsonb)') is null then
    raise exception using
      errcode = 'MX000',
      message = 'c3-pruebas NO se corrió: pega antes c1-plan-de-cuentas.sql, c2-libro.sql y c3-puentes.sql.';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Los ayudantes (en pg_temp: mueren con la sesión y nadie más los ve; se
-- llaman con su esquema delante, y siempre como el editor).
--   · c3_foto(): cómo están el libro, los papeles, las reglas, los
--     historiales, los contadores, las secuencias de las tablas de la app
--     y las huellas. La última prueba la compara con la del principio.
--   · c3_montar(): lo que usan casi todas las pruebas, dentro de su
--     subtransacción (el MXT00 lo deshace): una tarjeta de prueba (cuenta
--     2100-9998, últimos 4 «9998»), reglas CONFIRMADAS con nombres propios
--     («c3 pruebas material», «c3 pruebas tarjeta»…), la regla del tipo de
--     la obra confirmada, un supply y un ayudante (con su proveedor).
--   · c3_recibo(json): un recibo de prueba con su id (negativo), como lo
--     deja la lectura de cerebro: leído, con total, fecha, categoría y forma
--     de pago; subido el día de su fecha, salvo que se diga «creado».
--   · c3_lineas(asiento): las líneas en una línea de texto, para comparar.
--   · el reloj fingido y los cierres: los de c2-pruebas.
-- ---------------------------------------------------------------------
create or replace function pg_temp.c3_foto() returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_huellas text := '-';
  v_seq     text;
  v_rev     text := '-';
begin
  -- (puente_revisados, con SQL dinámico: así la foto también se saca con un
  -- c3-puentes.sql anterior, que no la tenía.)
  if to_regclass('public.puente_revisados') is not null then
    execute 'select count(*)::text from public.puente_revisados' into v_rev;
  end if;
  select left(md5(string_agg(h.tipo || ' ' || h.objeto || ' ' || h.md5, ',' order by h.tipo, h.objeto)), 12)
    into v_huellas
    from public.fn_libro_huellas_calcular() h;
  select string_agg(format('%s=%s', t, coalesce((select s.last_value from pg_sequences s
                                                   where s.schemaname || '.' || s.sequencename = pg_get_serial_sequence('public.' || t, 'id')),
                                                  0)), ' ' order by t)
    into v_seq
    from unnest(array['recibos', 'facturas', 'horas', 'trabajos_externos', 'materiales', 'externos_equipo']) t;
  return format('asientos=%s lineas=%s contadores=%s cerrados=%s puente=%s cobros=%s aplic=%s notas=%s reglas=%s/%s/%s/%s/%s '
                'prov=%s alias=%s hist=%s horas_apr=%s aprobadas=%s recibos=%s facturas=%s externos=%s horas=%s cuentas=%s '
                'cont_en=%s revisados=%s sec=[%s] huellas=%s',
                (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores),
                (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) || ':' || coalesce(sum(intentos), 0) from puente_documentos),
                (select count(*) from cobros), (select count(*) from aplicaciones_cobro), (select count(*) from notas_credito),
                (select count(*) from mapeo_categoria_recibo), (select count(*) from mapeo_metodo_pago),
                (select count(*) from mapeo_tipo_proyecto), (select count(*) from tarjetas), (select count(*) from puente_cuentas),
                (select count(*) from proveedores), (select count(*) from proveedores_alias),
                (select count(*) from puente_reglas_historial), (select count(*) from horas_aprobaciones),
                (select count(*) from horas where aprobado_el is not null),
                (select count(*) from recibos), (select count(*) from facturas), (select count(*) from trabajos_externos),
                (select count(*) from horas), (select count(*) from cuentas),
                (select count(*) from recibos where contabilizado_en is not null)
                  + (select count(*) from facturas where contabilizado_en is not null)
                  + (select count(*) from trabajos_externos where contabilizado_en is not null),
                v_rev, coalesce(v_seq, '-'), v_huellas);
end $$;
revoke execute on function pg_temp.c3_foto() from public, anon, authenticated, service_role;

create or replace function pg_temp.c3_montar() returns jsonb
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_obra text := current_setting('mx3.obra');
  v_tipo text;
  v_ing  text;
  v_prov uuid;
  v_pext uuid;
begin
  insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
  values ('2100-9998', 'c3-pruebas: tarjeta de prueba', 'c3 test card', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
  on conflict (codigo) do nothing;
  perform fn_tarjeta_alta('9998', '2100-9998', 'c3-pruebas: tarjeta');
  perform fn_mapeo_categoria('c3 pruebas material', current_setting('mx3.material'));
  perform fn_mapeo_categoria('c3 pruebas gasolina', current_setting('mx3.vehiculo'));
  perform fn_mapeo_metodo_pago('c3 pruebas tarjeta', 'tarjeta');
  perform fn_mapeo_metodo_pago('c3 pruebas cuenta', 'cuenta_proveedor');
  perform fn_mapeo_metodo_pago('c3 pruebas banco', 'banco', fn_puente_cuenta_de('banco'));
  perform fn_mapeo_metodo_pago('c3 pruebas reembolso', 'reembolso');
  select p.tipo into v_tipo from proyectos p where p.id = v_obra;
  select m.cuenta into v_ing from mapeo_tipo_proyecto m where m.tipo = fn_puente_normalizar(v_tipo);
  v_ing := coalesce(v_ing, (select c.codigo from cuentas c
                             where c.tipo = 'ingreso' and c.regla_obra = 'obligatoria' and c.activa and c.imputable
                             order by (c.codigo = '4010') desc, c.codigo limit 1));
  perform fn_mapeo_tipo_proyecto(v_tipo, v_ing);
  v_prov := fn_proveedor_alta('C3 PRUEBAS SUPPLY', 'Net 30', array['c3 pruebas supply inc']);
  insert into externos_equipo (id, nombre, costo_hora, activo) overriding system value
  values (-3900001, 'c3-pruebas ayudante', 20, true);
  v_pext := fn_proveedor_alta('C3 PRUEBAS AYUDANTE', null, '{}', -3900001);
  return jsonb_build_object('proveedor', v_prov, 'proveedor_ayudante', v_pext, 'externo', -3900001, 'ingreso', v_ing,
                            'tipo', v_tipo);
end $$;
revoke execute on function pg_temp.c3_montar() from public, anon, authenticated, service_role;

create or replace function pg_temp.c3_recibo(p jsonb) returns bigint
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_id bigint;
begin
  insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, creado, co, fecha, categoria, subtotal,
                       tax, num_recibo, metodo_pago, ultimos4)
  overriding system value
  values ((p->>'id')::bigint,
          case when p ? 'proyecto_id' then p->>'proyecto_id' else current_setting('mx3.obra') end,
          coalesce(p->>'ruta', 'recibos/c3-pruebas/' || (p->>'id') || '.jpg'),
          (p->>'total')::numeric, coalesce(p->>'proveedor', 'C3 PRUEBAS SUPPLY'), p->>'notas',
          coalesce(p->>'estado', 'leido'),
          coalesce((p->>'autor_id')::uuid, nullif(current_setting('mx3.dueno', true), '')::uuid),
          -- Subido el día de su fecha (a mediodía en Miami), salvo que la
          -- prueba diga otra cosa: el reloj de verdad del banco puede ser de
          -- antes del corte, y un recibo subido antes del corte es de antes
          -- del corte (c3, punto 6).
          coalesce((p->>'creado')::timestamptz,
                   (coalesce((p->>'fecha')::date, current_setting('mx3.desde')::date + 4) + time '12:00')
                     at time zone 'America/New_York'), p->>'co',
          case when p ? 'fecha' then (p->>'fecha')::date else current_setting('mx3.desde')::date + 4 end,
          coalesce(p->>'categoria', 'c3 pruebas material'), (p->>'subtotal')::numeric, (p->>'tax')::numeric,
          coalesce(p->>'num_recibo', 'C3-' || (p->>'id')),
          case when p ? 'metodo_pago' then p->>'metodo_pago' else 'c3 pruebas tarjeta' end,
          case when p ? 'ultimos4' then p->>'ultimos4' else '9998' end)
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function pg_temp.c3_recibo(jsonb) from public, anon, authenticated, service_role;

create or replace function pg_temp.c3_lineas(p_asiento uuid) returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(string_agg(concat_ws(':', l.cuenta, l.monto::text, coalesce(l.proyecto_id, '-'), coalesce(l.co, '-'),
                                       coalesce(l.tercero_tipo, '-'),
                                       coalesce(l.partida_tabla || '/' || l.partida_id, '-')), ' | ' order by l.orden), '(sin líneas)')
    from asiento_lineas l
   where l.asiento_id = p_asiento
$$;
revoke execute on function pg_temp.c3_lineas(uuid) from public, anon, authenticated, service_role;

-- El asiento vivo de un papel (sin su reverso de corrección), leído del
-- libro a mano (no con la ayudante del bloque B: en rojo no existe).
create or replace function pg_temp.c3_vivo(p_tabla text, p_id text) returns uuid
language sql
stable
set search_path = public, pg_temp
as $$
  select a.id
    from asientos a
   where a.origen_tabla = p_tabla and a.origen_id = p_id
     and a.camino not in ('reverso', 'reverso_automatico')
     and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')
   order by a.cadena_pos desc
   limit 1
$$;
revoke execute on function pg_temp.c3_vivo(text, text) from public, anon, authenticated, service_role;

-- El reloj fingido y los cierres, como en c2-pruebas.sql.
create or replace function pg_temp.c3_fingir_hoy(p_hoy date) returns void
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
revoke execute on function pg_temp.c3_fingir_hoy(date) from public, anon, authenticated, service_role;

create or replace function pg_temp.c3_cerrar_hasta(p_periodo text) returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_p  periodos;
  v_ap periodos;
  v_q  text;
begin
  if not exists (select 1 from pg_locks l
                  where l.locktype = 'relation' and l.relation = 'public.periodos'::regclass
                    and l.pid = pg_backend_pid() and l.granted
                    and l.mode in ('ExclusiveLock', 'AccessExclusiveLock')) then
    raise exception using errcode = 'MXT09',
      message = 'c3-pruebas: una prueba que cierra períodos toma antes lock table public.periodos in exclusive mode.';
  end if;
  select * into v_p from periodos where periodo = p_periodo;
  perform pg_temp.c3_fingir_hoy(v_p.hasta + 1);
  select * into v_ap from periodos where tipo = 'apertura' and estado = 'abierto' order by desde limit 1;
  if v_ap.periodo is not null
     and not exists (select 1 from asientos a
                      where a.periodo = v_ap.periodo and a.tipo = 'apertura' and a.reversa_a is null
                        and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino = 'reverso')) then
    perform fn_postear(jsonb_build_object(
      'tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
      'descripcion', 'c3-pruebas: apertura de prueba (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '1000.00'),
                                  jsonb_build_object('cuenta', current_setting('mx3.capital'), 'monto', '-1000.00'))));
  end if;
  for v_q in select p.periodo from periodos p
              where p.tipo in ('mes', 'apertura') and p.estado = 'abierto' and p.desde <= v_p.desde
              order by p.desde loop
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_q;
  end loop;
end $$;
revoke execute on function pg_temp.c3_cerrar_hasta(text) from public, anon, authenticated, service_role;

-- Los tres puentes diferidos, en immediate (dentro de la subtransacción de
-- la prueba: el MXT00 los devuelve a diferidos). Solo los que existen: en
-- rojo no hay ninguno, y la prueba sigue y dice qué no pasó.
create or replace function pg_temp.c3_inmediato() returns void
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_lista text;
begin
  select string_agg(quote_ident(t.tgname), ', ' order by t.tgname) into v_lista
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0;
  if v_lista is not null then
    execute 'set constraints ' || v_lista || ' immediate';
  end if;
end $$;
revoke execute on function pg_temp.c3_inmediato() from public, anon, authenticated, service_role;

-- La misma orden, en texto, para ejecutarla con OTRO rol (el de cerebro):
-- el puente corre como si ese rol confirmara.
create or replace function pg_temp.c3_inmediato_sql() returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce('set constraints ' || string_agg(quote_ident(t.tgname), ', ' order by t.tgname) || ' immediate', 'select 1')
    from pg_trigger t
   where t.tgname in ('trg_puente_recibos_despues', 'trg_puente_externos_despues', 'trg_puente_facturas_despues')
     and t.tgconstraint <> 0
$$;
revoke execute on function pg_temp.c3_inmediato_sql() from public, anon, authenticated, service_role;

-- El saldo de una partida en una cuenta, leído del libro (debe − haber).
create or replace function pg_temp.c3_saldo(p_cuenta text, p_tabla text, p_id text) returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(sum(l.monto), 0)
    from asiento_lineas l
   where l.cuenta = p_cuenta and l.partida_tabla = p_tabla and l.partida_id = p_id
$$;
revoke execute on function pg_temp.c3_saldo(text, text, text) from public, anon, authenticated, service_role;

-- Cuántos asientos tiene un papel como origen, y cuántos de ellos son
-- reversos: «2/1» = el asiento y su reverso.
create or replace function pg_temp.c3_cuantos(p_tabla text, p_id text) returns text
language sql
stable
set search_path = public, pg_temp
as $$
  select count(*) || '/' || count(*) filter (where a.camino in ('reverso', 'reverso_automatico'))
    from asientos a
   where a.origen_tabla = p_tabla and a.origen_id = p_id
$$;
revoke execute on function pg_temp.c3_cuantos(text, text) from public, anon, authenticated, service_role;

-- Una deuda de la APERTURA a nombre de un papel (partida tabla/id), como la
-- cargará f04: si la apertura sigue abierta, un asiento de apertura el día
-- de la apertura; si ya se cerró, un ajuste a la apertura (ajuste_cpa) en
-- el primer mes abierto. Contra el capital. Nulo si no hay apertura.
create or replace function pg_temp.c3_apertura(p_tabla text, p_id text, p_cuenta text, p_monto numeric,
                                               p_tercero_tipo text, p_tercero_id text) returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_ap  periodos;
  v_lin jsonb;
begin
  select * into v_ap from periodos where tipo = 'apertura' order by desde limit 1;
  if v_ap.periodo is null then
    return null;
  end if;
  v_lin := jsonb_build_array(
             jsonb_build_object('cuenta', current_setting('mx3.capital'), 'monto', p_monto::text),
             jsonb_strip_nulls(jsonb_build_object('cuenta', p_cuenta, 'monto', (-p_monto)::text, 'tercero_tipo', p_tercero_tipo,
                                                  'tercero_id', p_tercero_id, 'partida_tabla', p_tabla, 'partida_id', p_id)));
  if v_ap.estado = 'abierto' then
    return fn_postear(jsonb_build_object('tipo', 'apertura', 'fecha', to_char(v_ap.desde, 'YYYY-MM-DD'),
                                         'descripcion', 'c3-pruebas: apertura de prueba (se deshace)', 'lineas', v_lin))->>'numero';
  end if;
  return fn_postear(jsonb_build_object('tipo', 'ajuste_cpa', 'afecta_periodo', v_ap.periodo,
                                       'fecha', current_setting('mx3.desde'),
                                       'motivo', 'c3-pruebas: ajuste a la apertura de prueba (se deshace)',
                                       'descripcion', 'c3-pruebas: ajuste a la apertura (se deshace)', 'lineas', v_lin))->>'numero';
end $$;
revoke execute on function pg_temp.c3_apertura(text, text, text, numeric, text, text) from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Preparación: solo lee. Lo que usan todas las pruebas, en ajustes de la
-- sesión (mx3.*), que mueren con ella.
-- ---------------------------------------------------------------------
do $$
declare
  v_dueno   uuid;
  v_equipo  uuid;
  v_obra    text;
  v_mes     text;
  v_desde   date;
  v_sig     text;
  v_mat     text;
  v_veh     text;
  v_capital text;
begin
  select id into v_dueno from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_equipo from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  -- Una obra con tipo; mejor una sin retención pactada en su estimado (una
  -- factura de prueba de una obra con retención esperaría a que se diga).
  select p.id into v_obra from proyectos p
   where nullif(btrim(p.tipo), '') is not null
   order by exists (select 1 from estimados e where e.proyecto_id = p.id and coalesce(e.retencion_pct, 0) > 0), p.id
   limit 1;
  select periodo, desde into v_mes, v_desde from periodos
   where tipo = 'mes' and estado = 'abierto' and desde >= fn_puente_corte() order by desde limit 1;
  select periodo into v_sig from periodos
   where tipo = 'mes' and estado = 'abierto' and desde = (v_desde + interval '1 month')::date;
  select codigo into v_mat from cuentas
   where tipo = 'costo' and regla_obra = 'obligatoria' and regla_cost_code <> 'prohibida' and activa and imputable
   order by (codigo = '5100') desc, codigo limit 1;
  select codigo into v_veh from cuentas
   where tipo = 'gasto' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '6300') desc, codigo limit 1;
  select codigo into v_capital from cuentas
   where tipo = 'capital' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '3900') desc, codigo limit 1;
  perform set_config('mx3.dueno',    coalesce(v_dueno::text, ''), false);
  perform set_config('mx3.equipo',   coalesce(v_equipo::text, ''), false);
  perform set_config('mx3.obra',     coalesce(v_obra, ''), false);
  perform set_config('mx3.mes',      coalesce(v_mes, ''), false);
  perform set_config('mx3.desde',    coalesce(v_desde::text, ''), false);
  perform set_config('mx3.sig',      coalesce(v_sig, ''), false);
  perform set_config('mx3.material', coalesce(v_mat, ''), false);
  perform set_config('mx3.vehiculo', coalesce(v_veh, ''), false);
  perform set_config('mx3.capital',  coalesce(v_capital, ''), false);
  perform set_config('mx3.banco',    coalesce(fn_puente_cuenta_de('banco'), ''), false);
  perform set_config('mx3.foto',     pg_temp.c3_foto(), false);
end $$;


-- =====================================================================
-- Cada puente produce el asiento correcto
-- =====================================================================

-- 1. Un recibo con tarjeta, subido por Edgar desde la app (rol de la app):
--    Dr la cuenta del material por obra y CO, por el TOTAL con impuesto /
--    Cr la subcuenta de la tarjeta. Camino puente, con quién lo subió, y
--    el recibo apunta a su asiento.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mat   text := current_setting('mx3.material', true);
  v_id    uuid;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('lineas=%s:245.37:%s:CO-9:-:- | 2100-9998:-245.37:-:-:-:- camino=puente rol=authenticated quien=dueño '
                  'papel=apunta estado=contabilizado', v_mat, v_obra);
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (1, 'recibo con tarjeta: Dr material por obra (total con impuesto) / Cr la tarjeta', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    -- (Subido el día de su fecha: el reloj del banco puede ser de antes del
    -- corte, y un recibo subido antes del corte es de antes del corte.)
    insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, co, fecha, categoria, subtotal, tax,
                         num_recibo, metodo_pago, ultimos4, creado)
    overriding system value
    values (-3100001, v_obra, 'recibos/c3/1.jpg', 245.37, 'C3 PRUEBAS SUPPLY', 'c3-pruebas', 'leido', v_dueno, 'CO-9',
            v_desde + 4, 'c3 pruebas material', 229.32, 16.05, 'T-1', 'c3 pruebas tarjeta', '9998',
            ((v_desde + 4) + time '12:00') at time zone 'America/New_York');
    execute 'reset role';
    v_id := pg_temp.c3_vivo('recibos', '-3100001');
    select format('lineas=%s camino=%s rol=%s quien=%s papel=%s estado=%s', pg_temp.c3_lineas(v_id), a.camino, a.rol_bd,
                  case when a.usuario_id = v_dueno then 'dueño' else coalesce(a.usuario_id::text, '-') end,
                  case when r.contabilizado_en = v_id then 'apunta' else 'no apunta' end,
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100001'), '-'))
      into v_obt
      from recibos r left join asientos a on a.id = v_id
     where r.id = -3100001;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (1, 'recibo con tarjeta: Dr material por obra (total con impuesto) / Cr la tarjeta', v_esp,
                               coalesce(v_obt, 'no posteó'), coalesce(v_obt = v_esp, false));
end $$;

-- 2. Un recibo A CUENTA del supply: Cr 2010 a nombre del proveedor, con el
--    recibo como partida abierta. La CxP por proveedor lo enseña abierto.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mat   text := current_setting('mx3.material', true);
  v_f     jsonb;
  v_id    uuid;
  v_ter   text;
  v_cxp   numeric;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('lineas=%s:1288.10:%s:-:-:- | %s:-1288.10:-:-:proveedor:recibos/-3100002 tercero=el supply cxp_abierta=1288.10',
                  v_mat, v_obra, fn_puente_cuenta_de('cxp'));
  if v_obra is null or v_desde is null then
    insert into _pruebas values (2, 'recibo a cuenta: Cr 2010 por proveedor, partida abierta', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100002, 'total', '1288.10', 'tax', '84.27',
                                                 'metodo_pago', 'c3 pruebas cuenta', 'ultimos4', null));
    v_id := pg_temp.c3_vivo('recibos', '-3100002');
    select case when l.tercero_id = v_f->>'proveedor' then 'el supply' else coalesce(l.tercero_id, '-') end into v_ter
      from asiento_lineas l where l.asiento_id = v_id and l.tercero_tipo is not null;
    select c.saldo into v_cxp from cxp_abierta c where c.partida_tabla = 'recibos' and c.partida_id = '-3100002';
    v_obt := format('lineas=%s tercero=%s cxp_abierta=%s', pg_temp.c3_lineas(v_id), coalesce(v_ter, '-'), coalesce(v_cxp::text, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (2, 'recibo a cuenta: Cr 2010 por proveedor, partida abierta', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. Pagado por banco (cheque, ACH, Zelle): Cr la cuenta de banco. Y una
--    DEVOLUCIÓN (total en negativo, como la guarda la app): los signos se
--    dan vuelta solos.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mat   text := current_setting('mx3.material', true);
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('banco=%s:60.00:%s:-:-:- | %s:-60.00:-:-:-:- devolucion=%s:-45.99:%s:-:-:- | 2100-9998:45.99:-:-:-:-',
                  v_mat, v_obra, current_setting('mx3.banco', true), v_mat, v_obra);
  if v_obra is null or v_desde is null then
    insert into _pruebas values (3, 'pagado por banco, y una devolución', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100003, 'total', '60.00', 'metodo_pago', 'c3 pruebas banco', 'ultimos4', null));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100004, 'total', '-45.99', 'notas', 'DEVOLUCIÓN — c3-pruebas'));
    v_obt := format('banco=%s devolucion=%s', pg_temp.c3_lineas(pg_temp.c3_vivo('recibos', '-3100003')),
                    pg_temp.c3_lineas(pg_temp.c3_vivo('recibos', '-3100004')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (3, 'pagado por banco, y una devolución', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. Reembolso: lo pagó de su bolsillo quien subió el recibo. Un empleado
--    → 2250 a su nombre; Edgar → 2900. Los dos abren su partida.
do $$
declare
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_ter    text;
  v_obt    text;
  v_esp    text;
begin
  v_esp := format('empleado=%s:-30.00:-:-:empleado:recibos/-3100005 a_nombre_de=el empleado dueno=%s:-40.00:-:-:-:recibos/-3100006',
                  fn_puente_cuenta_de('reembolso_empleado'), fn_puente_cuenta_de('reembolso_dueno'));
  if v_obra is null or v_desde is null or v_dueno is null or v_equipo is null then
    insert into _pruebas values (4, 'reembolso: empleado → 2250 a su nombre; Edgar → 2900', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100005, 'total', '30.00', 'metodo_pago', 'c3 pruebas reembolso',
                                                 'ultimos4', null, 'autor_id', v_equipo));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100006, 'total', '40.00', 'metodo_pago', 'c3 pruebas reembolso',
                                                 'ultimos4', null, 'autor_id', v_dueno));
    select case when l.tercero_id = v_equipo::text then 'el empleado' else coalesce(l.tercero_id, '-') end into v_ter
      from asiento_lineas l where l.asiento_id = pg_temp.c3_vivo('recibos', '-3100005') and l.monto < 0;
    v_obt := format('empleado=%s a_nombre_de=%s dueno=%s',
                    split_part(pg_temp.c3_lineas(pg_temp.c3_vivo('recibos', '-3100005')), ' | ', 2), coalesce(v_ter, '-'),
                    split_part(pg_temp.c3_lineas(pg_temp.c3_vivo('recibos', '-3100006')), ' | ', 2));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (4, 'reembolso: empleado → 2250 a su nombre; Edgar → 2900', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 5. Un trabajo externo (el ayudante por horas): Dr 5200 por obra / Cr 2010
--    con su propia partida, a nombre del proveedor enlazado al ayudante.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_ter   text;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('lineas=%s:320.00:%s:-:-:- | %s:-320.00:-:-:proveedor:trabajos_externos/-3100007 tercero=el ayudante',
                  fn_puente_cuenta_de('subcontratos'), v_obra, fn_puente_cuenta_de('cxp'));
  if v_obra is null or v_desde is null then
    insert into _pruebas values (5, 'trabajo externo: Dr 5200 por obra / Cr 2010 con su partida', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, externo_id) overriding system value
    values (-3100007, v_obra, 'c3-pruebas ayudante, demolición 2 días', v_desde + 2, 'horas', 16, 320.00, -3900001);
    select case when l.tercero_id = v_f->>'proveedor_ayudante' then 'el ayudante' else coalesce(l.tercero_id, '-') end into v_ter
      from asiento_lineas l where l.asiento_id = pg_temp.c3_vivo('trabajos_externos', '-3100007') and l.monto < 0;
    v_obt := format('lineas=%s tercero=%s', pg_temp.c3_lineas(pg_temp.c3_vivo('trabajos_externos', '-3100007')), coalesce(v_ter, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (5, 'trabajo externo: Dr 5200 por obra / Cr 2010 con su partida', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 6. Una factura emitida con retención: Dr 1110 lo que se cobra ahora y
--    1120 la retención (las dos con la factura como partida, por obra) / Cr
--    el ingreso del tipo de su obra, por el total.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_obt   text;
  v_esp   text;
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (6, 'factura con retención: Dr 1110 + 1120 / Cr el ingreso de su tipo de obra', '-',
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    v_esp := format('lineas=%s:9000.00:%s:-:-:facturas/-3100008 | %s:1000.00:%s:-:-:facturas/-3100008 | %s:-10000.00:%s:-:-:- estado=emitida',
                    fn_puente_cuenta_de('cxc'), v_obra, fn_puente_cuenta_de('retencion_cxc'), v_obra, v_f->>'ingreso', v_obra);
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3100008, v_obra, 'C3-8', v_desde + 9, 10000.00, 1000.00);
    select format('lineas=%s estado=%s', pg_temp.c3_lineas(pg_temp.c3_vivo('facturas', '-3100008')), f.estado) into v_obt
      from facturas f where f.id = -3100008;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (6, 'factura con retención: Dr 1110 + 1120 / Cr el ingreso de su tipo de obra', coalesce(v_esp, '-'),
                               v_obt, v_obt = v_esp);
end $$;


-- =====================================================================
-- El contrato: idempotencia, cuándo, cambios, anulado, borrado, corte,
-- tardío
-- =====================================================================

-- 7. Idempotencia: el trigger contabiliza el recibo; después Edgar corre
--    el backfill dos veces desde la app y le cambia la nota con ✎ (algo que
--    el libro no usa). Nada se duplica ni se reversa, y el estado del papel
--    ni se mueve.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_antes text;
  v_r1    jsonb;
  v_r2    jsonb;
  v_obt   text;
  v_esp   text := 'asientos=1/0 correr=2_veces_sin_error estado_igual=t';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (7, 'idempotencia: backfill dos veces y una nota nueva no duplican', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100009, 'total', '99.99'));
    select d.estado || d.intentos || coalesce(d.asiento_id::text, '') into v_antes
      from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100009';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r1 := fn_puentes_correr();
    v_r2 := fn_puentes_correr();
    update recibos set notas = 'c3-pruebas: otra nota' where id = -3100009;
    execute 'reset role';
    v_obt := format('asientos=%s correr=%s estado_igual=%s', pg_temp.c3_cuantos('recibos', '-3100009'),
                    case when v_r1 ? 'pasados' and v_r2 ? 'pasados' and (v_r1->>'errores') = '0' and (v_r2->>'errores') = '0'
                         then '2_veces_sin_error' else coalesce(v_r2::text, '-') end,
                    (select d.estado || d.intentos || coalesce(d.asiento_id::text, '') from puente_documentos d
                      where d.tabla = 'recibos' and d.documento_id = '-3100009') is not distinct from v_antes
                    and v_antes is not null);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (7, 'idempotencia: backfill dos veces y una nota nueva no duplican', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 8. Un recibo 'por_leer' NO se contabiliza, con o sin total: espera a la
--    lectura. No le toca a Edgar, así que no sale en la bandeja... salvo
--    que lleve más de dos días esperando (la rutina no lo leyó).
do $$
declare
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_hoy    bigint;
  v_obt    text;
  v_esp    text := 'sin_total=espera/por_leer con_total=espera/por_leer asientos=0 bandeja_hoy=0 bandeja_a_los_3_dias=2';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (8, 'un recibo por_leer no se contabiliza (con o sin total)', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    -- Como lo sube la app: sin total, sin fecha, sin forma de pago (subido
    -- el día 5 del mes, que es lo que cuenta sin fecha).
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100010, 'estado', 'por_leer', 'total', null, 'fecha', null,
                                                 'metodo_pago', null, 'ultimos4', null, 'proveedor', null, 'categoria', 'material',
                                                 'creado', ((v_desde + 4) + time '12:00')::text,
                                                 'autor_id', coalesce(v_equipo, nullif(current_setting('mx3.dueno', true), '')::uuid)));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100011, 'estado', 'por_leer', 'total', '412.00'));
    select count(*) into v_hoy from puentes_bandeja b where b.tabla = 'recibos' and b.documento_id in ('-3100010', '-3100011');
    update puente_documentos set actualizado = now() - interval '3 days'
     where tabla = 'recibos' and documento_id in ('-3100010', '-3100011');
    select format('sin_total=%s con_total=%s asientos=%s bandeja_hoy=%s bandeja_a_los_3_dias=%s',
                  (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100010'),
                  (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100011'),
                  (select count(*) from asientos where origen_tabla = 'recibos' and origen_id in ('-3100010', '-3100011')),
                  v_hoy,
                  (select count(*) from puentes_bandeja b where b.tabla = 'recibos' and b.documento_id in ('-3100010', '-3100011')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (8, 'un recibo por_leer no se contabiliza (con o sin total)', v_esp, coalesce(v_obt, 'no pasó por el puente'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 9. Un metodo_pago que el mapeo no conoce («APPLE PAY ??») o vacío NO
--    postea: el recibo queda en la bandeja, con el texto tal cual y qué
--    hacer. (Vacío y de un proveedor SIN cuenta abierta: con términos iría a
--    su cuenta, prueba 70.)
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_obt   text;
  v_esp   text := 'raro=pendiente/metodo_pago en_bandeja=t dice_el_texto=t vacio=pendiente/metodo_pago asientos=0';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (9, 'metodo_pago desconocido o vacío: a la bandeja, sin asiento', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100012, 'total', '60.00', 'metodo_pago', 'APPLE PAY ??c3', 'ultimos4', '0092'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100013, 'total', '19.99', 'metodo_pago', null, 'ultimos4', null,
                                                 'proveedor', 'c3 pruebas sin cuenta'));
    select format('raro=%s en_bandeja=%s dice_el_texto=%s vacio=%s asientos=%s',
                  (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100012'),
                  exists (select 1 from puentes_bandeja b where b.tabla = 'recibos' and b.documento_id = '-3100012'),
                  exists (select 1 from puentes_bandeja b where b.tabla = 'recibos' and b.documento_id = '-3100012'
                                                           and b.motivo like '%APPLE PAY ??c3%'),
                  (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100013'),
                  (select count(*) from asientos where origen_tabla = 'recibos' and origen_id in ('-3100012', '-3100013')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (9, 'metodo_pago desconocido o vacío: a la bandeja, sin asiento', v_esp, coalesce(v_obt, 'no pasó por el puente'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 10. Una regla en BORRADOR no postea: el recibo espera en la bandeja; Edgar
--     la confirma, corre el backfill y entra.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_antes text;
  v_obt   text;
  v_esp   text := 'borrador=pendiente/categoria_borrador confirmada=contabilizado asientos=1';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (10, 'una regla en borrador no postea; confirmada, el backfill la contabiliza', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into mapeo_categoria_recibo (categoria, cuenta) values ('c3 pruebas borrador', current_setting('mx3.material'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100014, 'total', '77.00', 'categoria', 'c3 pruebas borrador'));
    select d.estado || '/' || d.codigo into v_antes from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100014';
    perform fn_mapeo_confirmar('categoria', 'c3 pruebas borrador');
    perform fn_puentes_correr();
    select format('borrador=%s confirmada=%s asientos=%s', coalesce(v_antes, '-'), d.estado,
                  (select count(*) from asientos where origen_tabla = 'recibos' and origen_id = '-3100014'))
      into v_obt
      from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100014';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (10, 'una regla en borrador no postea; confirmada, el backfill la contabiliza', v_esp,
                               coalesce(v_obt, 'no pasó por el puente'), coalesce(v_obt = v_esp, false));
end $$;

-- 11. Un recibo A CUENTA contabilizado y después ANULADO (como lo hace la
--     app o la lectura: estado 'anulado'): su asiento se reversa (el espejo
--     lleva el mismo proveedor y la misma partida, que queda en cero), el
--     recibo deja de apuntar a un asiento vivo, y el motivo lo dice.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_orig  uuid;
  v_obt   text;
  v_esp   text := 'reverso=espejo motivo=anulado vivo=ninguno papel=sin_asiento cxp_partida=cerrada estado=no_aplica';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (11, 'recibo anulado: reverso espejo (proveedor y partida incluidos)', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100015, 'total', '500.00', 'metodo_pago', 'c3 pruebas cuenta', 'ultimos4', null));
    v_orig := pg_temp.c3_vivo('recibos', '-3100015');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set estado = 'anulado' where id = -3100015;
    execute 'reset role';
    select format('reverso=%s motivo=%s vivo=%s papel=%s cxp_partida=%s estado=%s',
                  case when v_orig is not null and exists (
                         select 1 from asientos r where r.reversa_a = v_orig and r.camino = 'reverso'
                            and not exists ((select l.cuenta, -l.monto, l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
                                               from asiento_lineas l where l.asiento_id = v_orig)
                                            except all
                                            (select l.cuenta, l.monto, l.tercero_tipo, l.tercero_id, l.partida_tabla, l.partida_id
                                               from asiento_lineas l where l.asiento_id = r.id)))
                       then 'espejo' else 'no' end,
                  coalesce((select case when r.motivo like '%anulado%' then 'anulado' else r.motivo end
                              from asientos r where r.reversa_a = v_orig and r.camino = 'reverso'), '-'),
                  coalesce(pg_temp.c3_vivo('recibos', '-3100015')::text, 'ninguno'),
                  (select case when r.contabilizado_en is null then 'sin_asiento' else 'apunta' end from recibos r where r.id = -3100015),
                  case when exists (select 1 from cxp_abierta c where c.partida_tabla = 'recibos' and c.partida_id = '-3100015')
                       then 'abierta' else 'cerrada' end,
                  (select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100015'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (11, 'recibo anulado: reverso espejo (proveedor y partida incluidos)', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 12. Edgar corrige el TOTAL de un recibo ya contabilizado con ✎ (lo de
--     siempre en la app): el libro no se edita. Queda el reverso (con qué
--     cambió) y un asiento nuevo que dice a cuál sustituye; el recibo
--     apunta al nuevo; y al confirmar, todo el libro sigue en verde.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_orig  uuid;
  v_nuevo uuid;
  v_ok    text;
  v_obt   text;
  v_esp   text := 'reverso=con_cambio sustituto=enlazado monto=247.37 papel=apunta_al_nuevo confirma=t libro=t';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (12, 'editar el total de un recibo contabilizado: reverso + sustituto enlazados', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100016, 'total', '245.37'));
    v_orig := pg_temp.c3_vivo('recibos', '-3100016');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set total = 247.37, proveedor = 'C3 PRUEBAS SUPPLY', notas = 'corregido', estado = 'leido' where id = -3100016;
    execute 'reset role';
    v_nuevo := pg_temp.c3_vivo('recibos', '-3100016');
    set constraints all immediate;   -- lo que hace el commit
    select case when bool_and(v.ok) then 't' else 'f' end into v_ok from fn_verificar_cadena() v;
    select format('reverso=%s sustituto=%s monto=%s papel=%s confirma=t libro=%s',
                  coalesce((select case when r.motivo like '%total: 245.37 → 247.37%' then 'con_cambio' else r.motivo end
                              from asientos r where r.reversa_a = v_orig and r.camino = 'reverso'), '-'),
                  case when (select a.sustituye_a from asientos a where a.id = v_nuevo) = v_orig then 'enlazado' else 'no' end,
                  coalesce((select l.monto::text from asiento_lineas l where l.asiento_id = v_nuevo and l.monto > 0), '-'),
                  (select case when r.contabilizado_en = v_nuevo and v_nuevo <> v_orig then 'apunta_al_nuevo' else 'no' end
                     from recibos r where r.id = -3100016),
                  v_ok)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (12, 'editar el total de un recibo contabilizado: reverso + sustituto enlazados', v_esp,
                               coalesce(v_obt, 'no posteó'), coalesce(v_obt = v_esp, false));
end $$;

-- 13. Borrar un recibo que ya está en el libro: NO, ni desde la app (Edgar)
--     ni desde el SQL Editor, y el mensaje dice qué hacer (el total en 0 con
--     ✎). Tampoco uno ya reversado: es el rastro de sus asientos. Uno que
--     nunca entró al libro se borra como siempre, y sale de la bandeja; y
--     uno guardado y borrado en la misma transacción no deja ni memoria.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_app   text;
  v_msg   text;
  v_ed    text;
  v_rev   text;
  v_libre text;
  v_misma text;
  v_obt   text;
  v_esp   text := 'app=MX003 dice_que_hacer=t editor=MX003 reversado=MX003 nunca_entro=borrado/sin_rastro_en_la_bandeja '
                  'misma_transaccion=sin_rastro';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (13, 'borrar un recibo del libro: rechazado con qué hacer; uno que nunca entró, sí', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    -- Guardado y borrado antes de confirmar (el puente, diferido, corre
    -- después, al ponerlo en immediate): no queda nada de él.
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100029, 'total', '55.00'));
    delete from recibos where id = -3100029;
    perform pg_temp.c3_inmediato();
    v_misma := case when exists (select 1 from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100029')
                      or exists (select 1 from asientos a where a.origen_tabla = 'recibos' and a.origen_id = '-3100029')
                    then 'con_rastro' else 'sin_rastro' end;
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100017, 'total', '120.00'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100018, 'total', '130.00'));
    update recibos set estado = 'anulado' where id = -3100018;
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100019, 'total', '140.00', 'metodo_pago', 'APPLE PAY ??c3'));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      delete from recibos where id = -3100017;
      v_app := 'entró';
    exception when others then
      v_app := sqlstate;
      v_msg := sqlerrm;
    end;
    begin
      delete from recibos where id = -3100019;
      v_libre := case when found then 'borrado' else 'no_borró' end;
    exception when others then
      v_libre := sqlstate;
    end;
    execute 'reset role';
    begin
      delete from recibos where id = -3100017;
      v_ed := 'entró';
    exception when others then
      v_ed := sqlstate;
    end;
    begin
      delete from recibos where id = -3100018;
      v_rev := 'entró';
    exception when others then
      v_rev := sqlstate;
    end;
    v_obt := format('app=%s dice_que_hacer=%s editor=%s reversado=%s nunca_entro=%s/%s misma_transaccion=%s', v_app,
                    coalesce(v_msg like '%no se borra%' and v_msg like '%total en 0%', false), v_ed, v_rev, v_libre,
                    case when exists (select 1 from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100019')
                         then 'sigue_en_la_bandeja' else 'sin_rastro_en_la_bandeja' end,
                    v_misma);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (13, 'borrar un recibo del libro: rechazado con qué hacer; uno que nunca entró, sí', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 14. Anular desde la app es ponerle el total en 0 con ✎: el libro lo
--     reversa y el recibo se queda como rastro. Desde Contabilidad,
--     fn_recibo_anular con su motivo, que queda escrito en el reverso.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_r     jsonb;
  v_obt   text;
  v_esp   text := 'total_cero=2/1:no_aplica/total_cero papel=se_queda anular=2/1:no_aplica/anulado motivo_escrito=t estado=anulado';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (14, 'anular: total en 0 con ✎, o fn_recibo_anular con su motivo', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100020, 'total', '64.00'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100021, 'total', '81.00'));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set total = 0, estado = 'leido', proveedor = 'C3 PRUEBAS SUPPLY', notas = 'c3-pruebas: repetido'
     where id = -3100020;
    v_r := fn_recibo_anular(-3100021, 'c3: se subió dos veces');
    execute 'reset role';
    select format('total_cero=%s:%s papel=%s anular=%s:%s motivo_escrito=%s estado=%s',
                  pg_temp.c3_cuantos('recibos', '-3100020'),
                  (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100020'),
                  case when exists (select 1 from recibos where id = -3100020) then 'se_queda' else 'borrado' end,
                  pg_temp.c3_cuantos('recibos', '-3100021'),
                  (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100021'),
                  exists (select 1 from asientos a
                           where a.origen_tabla = 'recibos' and a.origen_id = '-3100021' and a.camino = 'reverso'
                             and a.motivo like '%Motivo de Edgar: c3: se subió dos veces%'),
                  (select r.estado from recibos r where r.id = -3100021))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (14, 'anular: total en 0 con ✎, o fn_recibo_anular con su motivo', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 15. El GUARDARRAÍL: nada fechado antes del corte (1-oct-2026) entra por
--     puente. Un recibo, una factura y un trabajo externo de septiembre
--     quedan «no_aplica» (viven en QuickBooks y llegan con la apertura); el
--     backfill pedido desde el 1-sep empieza igual en el corte; y un cobro
--     de septiembre ni se registra.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_corte date := fn_puente_corte();
  v_r     jsonb;
  v_cob   text;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('recibo=no_aplica/antes_del_corte factura=no_aplica/antes_del_corte externo=no_aplica/antes_del_corte '
                  'correr_desde=%s asientos_de_puente_antes_del_corte=0 cobro=MX002', v_corte);
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (15, 'guardarraíl: nada antes del corte entra por puente', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    -- Papeles de septiembre subidos en septiembre (creado antes del corte):
    -- los que se suben después con fecha de antes esperan en la bandeja
    -- (prueba 53).
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100022, 'total', '88.00', 'fecha', (v_corte - 3)::text,
                                                 'creado', (v_corte - 3)::text || ' 15:00-04'));
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100023, v_obra, 'C3-23', v_corte - 16, 1500.00);
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, externo_id, creado) overriding system value
    values (-3100024, v_obra, 'c3-pruebas: ayudante de septiembre', v_corte - 11, 'horas', 10, 200.00, -3900001,
            ((v_corte - 11)::text || ' 18:00-04')::timestamptz);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_puentes_correr(v_corte - 30);
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_corte - 1)::text, 'monto', '100.00', 'aplicaciones',
                                                    jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '100.00'))));
      v_cob := 'entró';
    exception when others then
      v_cob := sqlstate;
    end;
    execute 'reset role';
    select format('recibo=%s factura=%s externo=%s correr_desde=%s asientos_de_puente_antes_del_corte=%s cobro=%s',
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3100022'), '-'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'facturas' and d.documento_id = '-3100023'), '-'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'trabajos_externos' and d.documento_id = '-3100024'), '-'),
                  coalesce(v_r->>'desde', '-'),
                  (select count(*) from asientos a where a.camino = 'puente' and a.fecha_contable < v_corte),
                  v_cob)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (15, 'guardarraíl: nada antes del corte entra por puente', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 16. Un documento TARDÍO: su mes ya está cerrado. Entra el primer día del
--     primer mes abierto, con la nota en su procedencia (§5.7 del plan). Y
--     un recibo de ese mes que se corrige después del cierre: su reverso y
--     su sustituto también van al mes abierto; el mes cerrado no se toca.
do $$
declare
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_sig    text := nullif(current_setting('mx3.sig', true), '');
  v_sigd   date;
  v_orig   uuid;
  v_nuevo  uuid;
  v_n_mes  bigint;
  v_obt    text;
  v_esp    text;
begin
  select p.desde into v_sigd from periodos p where p.periodo = v_sig;
  v_esp := format('tardio=%1$s/%2$s/normal nota=t corregido: reverso=%1$s sustituto=%1$s/nota=t mes_cerrado_intacto=t', v_sigd, v_sig);
  if v_obra is null or v_desde is null or v_sig is null then
    insert into _pruebas values (16, 'documento tardío: al primer día del mes abierto, con la nota', v_esp,
                                 'omitida: falta obra, o el mes abierto y el siguiente', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100025, 'total', '70.00', 'fecha', (v_desde + 6)::text));
    v_orig := pg_temp.c3_vivo('recibos', '-3100025');
    perform pg_temp.c3_cerrar_hasta(v_mes);
    select count(*) into v_n_mes from asientos where periodo = v_mes;
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100026, 'total', '88.00', 'fecha', (v_desde + 19)::text));
    update recibos set total = 75.00 where id = -3100025;
    v_nuevo := pg_temp.c3_vivo('recibos', '-3100025');
    select format('tardio=%s/%s/%s nota=%s corregido: reverso=%s sustituto=%s/nota=%s mes_cerrado_intacto=%s',
                  a.fecha_contable, a.periodo, a.tipo,
                  coalesce(a.procedencia->'tardio'->>'nota' like format('Documento tardío del %s: su mes (%s) ya estaba cerrado%%',
                                                                        v_desde + 19, v_mes), false),
                  (select r.fecha_contable from asientos r where r.reversa_a = v_orig and r.camino = 'reverso'),
                  (select s.fecha_contable from asientos s where s.id = v_nuevo and s.sustituye_a = v_orig),
                  coalesce((select s.procedencia ? 'tardio' from asientos s where s.id = v_nuevo), false),
                  (select count(*) from asientos where periodo = v_mes) = v_n_mes)
      into v_obt
      from asientos a
     where a.id = pg_temp.c3_vivo('recibos', '-3100026');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (16, 'documento tardío: al primer día del mes abierto, con la nota', v_esp, coalesce(v_obt, 'no posteó'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 17. Un documento tardío de un EJERCICIO ANTERIOR (el año ya pasó y su
--     diciembre está cerrado): entra el primer día del año abierto como
--     ajuste de ese ejercicio (ajuste_cpa, afecta_periodo = su mes), para no
--     caer en el resultado del año nuevo. El mismo criterio que c2 usa para
--     el reverso de un ejercicio anterior.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_dic   text;
  v_dicd  date;
  v_ene   text;
  v_ened  date;
  v_obt   text;
  v_esp   text;
begin
  if v_desde is not null then
    select p.periodo, p.desde into v_dic, v_dicd from periodos p
     where p.tipo = 'mes' and p.desde = make_date(extract(year from v_desde)::int, 12, 1);
    select p.periodo, p.desde into v_ene, v_ened from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int + 1, 1, 1);
  end if;
  v_esp := format('tipo=ajuste_cpa afecta=%s fecha=%s periodo=%s motivo=t', v_dic, v_ened, v_ene);
  if v_obra is null or v_dic is null or v_ene is null then
    insert into _pruebas values (17, 'tardío de un ejercicio anterior: ajuste_cpa de su mes', v_esp,
                                 'omitida: falta obra, o el diciembre del mes abierto y el enero siguiente', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_cerrar_hasta(v_dic);
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100027, 'total', '55.00', 'fecha', (v_dicd + 14)::text));
    select format('tipo=%s afecta=%s fecha=%s periodo=%s motivo=%s', a.tipo, a.afecta_periodo, a.fecha_contable, a.periodo,
                  coalesce(a.motivo like '%ejercicio anterior%', false))
      into v_obt
      from asientos a
     where a.id = pg_temp.c3_vivo('recibos', '-3100027');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (17, 'tardío de un ejercicio anterior: ajuste_cpa de su mes', v_esp, coalesce(v_obt, 'no posteó'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 18. Un cobro PARCIAL de una factura con retención, y después el cobro de
--     su retención: Dr el banco / Cr la partida de la factura en 1110 (o en
--     1120 la retención). Lo abierto baja con cada cobro; la retención no se
--     cobra de más; la casilla «pagada» de la app no se toca.
do $$
declare
  v_dueno   uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra    text := nullif(current_setting('mx3.obra', true), '');
  v_desde   date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cxc     text := fn_puente_cuenta_de('cxc');
  v_ret     text := fn_puente_cuenta_de('retencion_cxc');
  v_banco   text := current_setting('mx3.banco', true);
  v_r1      jsonb;
  v_r2      jsonb;
  v_abierto text;
  v_mas     text;
  v_obt     text;
  v_esp     text;
begin
  v_esp := format('parcial=%1$s:4000.00:-:-:-:- | %2$s:-4000.00:%4$s:-:-:facturas/-3100040 abierto=5000.00/1000.00 '
                  'retencion=%1$s:1000.00:-:-:-:- | %3$s:-1000.00:%4$s:-:-:facturas/-3100040 abierto=5000.00/0.00 '
                  'retencion_de_mas=MX008 libro=5000.00/5000.00 app=f/0.00',
                  v_banco, v_cxc, v_ret, v_obra);
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (18, 'cobro parcial y cobro de la retención', v_esp, 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3100040, v_obra, 'C3-40', v_desde + 2, 10000.00, 1000.00);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r1 := fn_cobro_registrar(jsonb_build_object(
              'fecha', (v_desde + 10)::text, 'monto', '4000.00', 'medio', 'cheque', 'referencia', 'c3-1',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100040, 'monto', '4000.00'))));
    execute 'reset role';
    v_abierto := pg_temp.c3_saldo(v_cxc, 'facturas', '-3100040') || '/' || pg_temp.c3_saldo(v_ret, 'facturas', '-3100040');
    execute 'set local role authenticated';
    v_r2 := fn_cobro_registrar(jsonb_build_object(
              'fecha', (v_desde + 20)::text, 'monto', '1000.00', 'medio', 'ach',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100040, 'monto', '1000.00', 'es_retencion', true))));
    begin
      perform fn_cobro_registrar(jsonb_build_object(
                'fecha', (v_desde + 21)::text, 'monto', '1.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100040, 'monto', '1.00', 'es_retencion', true))));
      v_mas := 'entró';
    exception when others then
      v_mas := sqlstate;
    end;
    execute 'reset role';
    select format('parcial=%s abierto=%s retencion=%s abierto=%s retencion_de_mas=%s libro=%s/%s app=%s/%s',
                  pg_temp.c3_lineas(pg_temp.c3_vivo('cobros', v_r1->>'cobro')), v_abierto,
                  pg_temp.c3_lineas(pg_temp.c3_vivo('cobros', v_r2->>'cobro')),
                  pg_temp.c3_saldo(v_cxc, 'facturas', '-3100040') || '/' || pg_temp.c3_saldo(v_ret, 'facturas', '-3100040'),
                  v_mas, fc.saldo_libro, fc.cobrado_libro, fc.pagada, fc.cobrado_app)
      into v_obt
      from facturas_cobro fc
     where fc.id = -3100040;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (18, 'cobro parcial y cobro de la retención', v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 19. Un cobro que paga DOS facturas, una con descuento: una línea por
--     factura, y el descuento baja el ingreso de la suya. Lo que no cabe se
--     rechaza: cobrar de más (MX008), aplicaciones que no suman el cobro
--     (MX001), milésimas (MX005), y anular una factura que ya tiene cobros
--     (MX008: primero se anula el cobro).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cxc   text := fn_puente_cuenta_de('cxc');
  v_banco text := current_setting('mx3.banco', true);
  v_f     jsonb;
  v_r     jsonb;
  v_mas   text;
  v_suma  text;
  v_mil   text;
  v_anu   text;
  v_obt   text;
  v_esp   text;
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (19, 'un cobro de dos facturas con descuento; lo que no cabe se rechaza', '-',
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    v_esp := format('lineas=%1$s:4950.00:-:-:-:- | %2$s:-3000.00:%3$s:-:-:facturas/-3100042 | %4$s:50.00:%3$s:-:-:- | '
                    '%2$s:-2000.00:%3$s:-:-:facturas/-3100041 saldos=0.00/0.00 de_mas=MX008 no_suma=MX001 milesimas=MX005 '
                    'anular_cobrada=MX008', v_banco, v_cxc, v_obra, v_f->>'ingreso');
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100041, v_obra, 'C3-41', v_desde + 2, 2000.00), (-3100042, v_obra, 'C3-42', v_desde + 2, 3000.00);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_cobro_registrar(jsonb_build_object(
             'fecha', (v_desde + 12)::text, 'monto', '4950.00', 'medio', 'cheque', 'referencia', 'c3-2',
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100041, 'monto', '2000.00'),
                                               jsonb_build_object('factura_id', -3100042, 'monto', '2950.00', 'descuento', '50.00'))));
    begin
      perform fn_cobro_registrar(jsonb_build_object(
                'fecha', (v_desde + 13)::text, 'monto', '100.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100041, 'monto', '100.00'))));
      v_mas := 'entró';
    exception when others then
      v_mas := sqlstate;
    end;
    begin
      perform fn_cobro_registrar(jsonb_build_object(
                'fecha', (v_desde + 13)::text, 'monto', '100.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '90.00'))));
      v_suma := 'entró';
    exception when others then
      v_suma := sqlstate;
    end;
    begin
      perform fn_cobro_registrar(jsonb_build_object(
                'fecha', (v_desde + 13)::text, 'monto', '10.005',
                'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '10.005'))));
      v_mil := 'entró';
    exception when others then
      v_mil := sqlstate;
    end;
    begin
      perform fn_factura_anular(-3100041, 'c3: se facturó mal', v_desde + 14);
      v_anu := 'entró';
    exception when others then
      v_anu := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('lineas=%s saldos=%s/%s de_mas=%s no_suma=%s milesimas=%s anular_cobrada=%s',
                    pg_temp.c3_lineas(pg_temp.c3_vivo('cobros', v_r->>'cobro')),
                    pg_temp.c3_saldo(v_cxc, 'facturas', '-3100041'), pg_temp.c3_saldo(v_cxc, 'facturas', '-3100042'),
                    v_mas, v_suma, v_mil, v_anu);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (19, 'un cobro de dos facturas con descuento; lo que no cabe se rechaza', coalesce(v_esp, '-'),
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 20. Un ANTICIPO: un cobro sin factura queda a favor del cliente en su obra
--     (Cr 1110 con el cobro como partida). Después se aplica a una factura,
--     sin dinero nuevo y solo hasta lo que tiene; y si el cheque rebota,
--     anular el cobro reversa también lo aplicado. Un cobro no se edita ni
--     se borra.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cxc   text := fn_puente_cuenta_de('cxc');
  v_r     jsonb;
  v_c     text;
  v_ant   text;
  v_apl   text;
  v_mas   text;
  v_ed    text;
  v_bo    text;
  v_obt   text;
  v_esp   text := 'anticipo=-1500.00 aplicado=-500.00/0.00 de_mas=MX008 anulado=0.00/1000.00/anulado editar=MX003 borrar=MX003';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (20, 'anticipo: a favor del cliente, se aplica, y se anula con el cobro', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100043, v_obra, 'C3-43', v_desde + 5, 1000.00), (-3100048, v_obra, 'C3-48', v_desde + 5, 600.00);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_cobro_registrar(jsonb_build_object(
             'fecha', (v_desde + 3)::text, 'monto', '1500.00', 'medio', 'zelle', 'referencia', 'c3-anticipo', 'proyecto_id', v_obra,
             'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '1500.00'))));
    v_c := v_r->>'cobro';
    execute 'reset role';
    v_ant := pg_temp.c3_saldo(v_cxc, 'cobros', v_c)::text;
    execute 'set local role authenticated';
    perform fn_anticipo_aplicar(v_c::uuid, -3100043, '1000.00', v_desde + 6);
    begin
      perform fn_anticipo_aplicar(v_c::uuid, -3100048, '600.00', v_desde + 6);
      v_mas := 'entró';
    exception when others then
      v_mas := sqlstate;
    end;
    execute 'reset role';
    v_apl := pg_temp.c3_saldo(v_cxc, 'cobros', v_c) || '/' || pg_temp.c3_saldo(v_cxc, 'facturas', '-3100043');
    execute 'set local role authenticated';
    perform fn_cobro_anular(v_c::uuid, 'c3: el cheque rebotó');
    execute 'reset role';
    begin
      update cobros set referencia = 'c3-otra' where id = v_c::uuid;
      v_ed := 'entró';
    exception when others then
      v_ed := sqlstate;
    end;
    begin
      delete from cobros where id = v_c::uuid;
      v_bo := 'entró';
    exception when others then
      v_bo := sqlstate;
    end;
    v_obt := format('anticipo=%s aplicado=%s de_mas=%s anulado=%s/%s/%s editar=%s borrar=%s', v_ant, v_apl, v_mas,
                    pg_temp.c3_saldo(v_cxc, 'cobros', v_c), pg_temp.c3_saldo(v_cxc, 'facturas', '-3100043'),
                    (select c.estado from cobros c where c.id = v_c::uuid), v_ed, v_bo);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (20, 'anticipo: a favor del cliente, se aplica, y se anula con el cobro', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 21. REGRESIÓN «marcar pagada»: Edgar toca ✓ en una factura contabilizada
--     (la app manda pagada = true). La app sigue igual: cobrado = monto (el
--     trigger de siempre). Y el libro no inventa dinero: ni asiento nuevo ni
--     reverso; el cobro llega con el banco (f06) o con fn_cobro_registrar, y
--     facturas_cobro lo avisa. Una factura que QuickBooks trae ya pagada
--     entra igual, y sin dinero.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_obt   text;
  v_esp   text := 'cobrado=800.00 asientos=1/0 aviso=t nace_pagada=500.00/1/0';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (21, 'marcar pagada: cobrado = monto como siempre, y sin dinero en el libro', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100044, v_obra, 'C3-44', v_desde + 3, 800.00);
    insert into facturas (id, proyecto_id, num, fecha, monto, pagada) overriding system value
    values (-3100049, v_obra, 'C3-49', v_desde + 3, 500.00, true);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update facturas set pagada = true where id = -3100044;
    execute 'reset role';
    select format('cobrado=%s asientos=%s aviso=%s nace_pagada=%s/%s', f.cobrado, pg_temp.c3_cuantos('facturas', '-3100044'),
                  coalesce((select fc.aviso like 'pagada en la app y abierta en el libro%' from facturas_cobro fc where fc.id = -3100044),
                           false),
                  (select g.cobrado from facturas g where g.id = -3100049), pg_temp.c3_cuantos('facturas', '-3100049'))
      into v_obt
      from facturas f
     where f.id = -3100044;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (21, 'marcar pagada: cobrado = monto como siempre, y sin dinero en el libro', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 22. Una factura ya contabilizada: su monto no cambia (MX003, con cómo se
--     anula) y no se borra; lo de la app (pagada) sí cambia. Se anula con su
--     NOTA DE CRÉDITO: número propio sin huecos, el espejo exacto de su
--     asiento; la factura se queda (anulada, con su asiento vivo) y su
--     partida queda en cero. Una anulada no vuelve.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cxc   text := fn_puente_cuenta_de('cxc');
  v_anio  int;
  v_nc    text;
  v_fact  uuid;
  v_ncas  uuid;
  v_m     text;
  v_msg   text;
  v_p     text;
  v_b     text;
  v_v     text;
  v_r     jsonb;
  v_obt   text;
  v_esp   text;
begin
  if v_desde is not null then
    v_anio := extract(year from v_desde + 10)::int;
    v_nc := format('NC-%s-%s', v_anio,
                   lpad((coalesce((select c.ultimo from contadores c where c.serie = 'notas_credito-' || v_anio), 0) + 1)::text, 4, '0'));
  end if;
  v_esp := format('monto=MX003/dice_como pagada=ok borrar=MX003 nc=%s espejo=t factura_viva=t saldo=0.00 estado=anulada volver=MX003',
                  v_nc);
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (22, 'factura contabilizada: no se edita ni se borra; se anula con nota de crédito', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100045, v_obra, 'C3-45', v_desde + 2, 1200.00);
    v_fact := pg_temp.c3_vivo('facturas', '-3100045');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update facturas set monto = 1300.00 where id = -3100045;
      v_m := 'entró';
    exception when others then
      v_m := sqlstate;
      v_msg := sqlerrm;
    end;
    begin
      update facturas set pagada = true where id = -3100045;
      v_p := 'ok';
    exception when others then
      v_p := sqlstate;
    end;
    begin
      delete from facturas where id = -3100045;
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    v_r := fn_factura_anular(-3100045, 'c3: se facturó dos veces', v_desde + 10);
    begin
      update facturas set estado = 'emitida' where id = -3100045;
      v_v := 'entró';
    exception when others then
      v_v := sqlstate;
    end;
    execute 'reset role';
    v_ncas := (select pg_temp.c3_vivo('notas_credito', n.id::text) from notas_credito n where n.anula_a = -3100045);
    select format('monto=%s pagada=%s borrar=%s nc=%s espejo=%s factura_viva=%s saldo=%s estado=%s volver=%s',
                  v_m || case when v_msg like '%fn_factura_anular%' then '/dice_como' else '' end, v_p, v_b,
                  coalesce(v_r->>'nota_credito', '-'),
                  v_ncas is not null
                  and (select count(*) from asiento_lineas l where l.asiento_id = v_ncas)
                      = (select count(*) from asiento_lineas l where l.asiento_id = v_fact)
                  and not exists ((select l.cuenta, -l.monto, l.proyecto_id, l.partida_tabla, l.partida_id
                                     from asiento_lineas l where l.asiento_id = v_fact)
                                  except all
                                  (select l.cuenta, l.monto, l.proyecto_id, l.partida_tabla, l.partida_id
                                     from asiento_lineas l where l.asiento_id = v_ncas)),
                  pg_temp.c3_vivo('facturas', '-3100045') is not distinct from v_fact and v_fact is not null,
                  pg_temp.c3_saldo(v_cxc, 'facturas', '-3100045'), f.estado, v_v)
      into v_obt
      from facturas f
     where f.id = -3100045;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (22, 'factura contabilizada: no se edita ni se borra; se anula con nota de crédito', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 23. Una factura en BORRADOR (la facturación propia de f10) no se
--     contabiliza: espera. Al emitirse, entra. Emitida y en el libro, no
--     vuelve a borrador.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_1     text;
  v_v     text;
  v_obt   text;
  v_esp   text := 'borrador=espera/borrador:0/0 emitida=contabilizado:1/0 volver=MX003';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (23, 'factura en borrador: espera; emitida, entra; no vuelve a borrador', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, estado) overriding system value
    values (-3100046, v_obra, 'C3-46', v_desde + 4, 700.00, 'borrador');
    select coalesce(d.estado || '/' || d.codigo, '-') || ':' || pg_temp.c3_cuantos('facturas', '-3100046') into v_1
      from (select 1) x left join puente_documentos d on d.tabla = 'facturas' and d.documento_id = '-3100046';
    update facturas set estado = 'emitida' where id = -3100046;
    begin
      update facturas set estado = 'borrador' where id = -3100046;
      v_v := 'entró';
    exception when others then
      v_v := sqlstate;
    end;
    select format('borrador=%s emitida=%s:%s volver=%s', v_1, coalesce(d.estado, '-'), pg_temp.c3_cuantos('facturas', '-3100046'), v_v)
      into v_obt
      from (select 1) x left join puente_documentos d on d.tabla = 'facturas' and d.documento_id = '-3100046';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (23, 'factura en borrador: espera; emitida, entra; no vuelve a borrador', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 24. El doble toque sin señal: el teléfono manda el mismo recibo dos veces
--     con la misma llave, y la segunda no entra (23505, que la app ya dice
--     «Eso ya estaba guardado; no se apuntó dos veces»). Sin llave (la app
--     de hoy) entran como siempre. Y la llave de un recibo no cambia.
do $$
declare
  v_quien uuid := coalesce(nullif(current_setting('mx3.equipo', true), '')::uuid,
                           nullif(current_setting('mx3.dueno', true), '')::uuid);
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_2     text;
  v_c     text;
  v_obt   text;
  v_esp   text := 'segundo=23505 sin_llave=2 cambiar_llave=MX003';
begin
  if v_quien is null or v_obra is null then
    insert into _pruebas values (24, 'la llave del teléfono: el doble toque entra una vez', v_esp, 'omitida: falta alguien activo u obra', null);
    return;
  end if;
  begin
    perform pg_temp.c3_inmediato();
    perform set_config('request.jwt.claims', json_build_object('sub', v_quien, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    insert into recibos (id, proyecto_id, ruta, notas, co, autor_id, llave_cliente)
    values (-3100200, v_obra, 'recibos/c3-pruebas/200.jpg', 'c3-pruebas', null, v_quien, 'c3-llave-1');
    begin
      insert into recibos (id, proyecto_id, ruta, notas, co, autor_id, llave_cliente)
      values (-3100201, v_obra, 'recibos/c3-pruebas/200.jpg', 'c3-pruebas', null, v_quien, 'c3-llave-1');
      v_2 := 'entró';
    exception when others then
      v_2 := sqlstate;
    end;
    insert into recibos (id, proyecto_id, ruta, notas, autor_id)
    values (-3100202, v_obra, 'recibos/c3-pruebas/202.jpg', 'c3-pruebas', v_quien),
           (-3100203, v_obra, 'recibos/c3-pruebas/203.jpg', 'c3-pruebas', v_quien);
    execute 'reset role';
    begin
      update recibos set llave_cliente = 'c3-llave-otra' where id = -3100200;
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
    end;
    v_obt := format('segundo=%s sin_llave=%s cambiar_llave=%s', v_2,
                    (select count(*) from recibos where id in (-3100202, -3100203)), v_c);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (24, 'la llave del teléfono: el doble toque entra una vez', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 25. Las HORAS nunca postean dinero. Un trabajador reporta sus horas como
--     la app (con su llave, y leyendo lo que guardó); Edgar las aprueba con
--     un toque por empleado: quedan aprobado_por / aprobado_el, en la vista
--     de horas aprobadas por obra y período (horas, no dólares) y en su
--     rastro. El libro no se mueve.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_dia    date;
  v_n0     bigint;
  v_otros  bigint;
  v_otrash numeric;
  v_id     bigint;
  v_ap     jsonb;
  v_obt    text;
  v_esp    text;
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (25, 'horas: el equipo reporta, Edgar aprueba; ni un dólar en el libro', '-',
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  v_dia := v_desde + 25;
  select count(*), coalesce(sum(h.horas), 0) into v_otros, v_otrash
    from horas h where h.usuario_id = v_equipo and h.fecha = v_dia and h.aprobado_el is null;
  v_esp := format('reporta=-3100300 asientos_nuevos=0 aprobar=%s/%s por=dueño vista=%s/8.5/1 rastro=aprobada',
                  v_otros + 1, v_otrash + 8.5, v_mes);
  begin
    select count(*) into v_n0 from asientos;
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, notas, co, llave_cliente)
    values (-3100300, v_dia, v_equipo, v_obra, 'rough-in', 8.5, 'c3-pruebas', 'C3-CO', 'c3-horas-1')
    returning id into v_id;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_ap := fn_horas_aprobar(v_equipo, v_dia, v_dia);
    execute 'reset role';
    select format('reporta=%s asientos_nuevos=%s aprobar=%s/%s por=%s vista=%s rastro=%s', v_id,
                  (select count(*) from asientos) - v_n0, v_ap->>'reportes', v_ap->>'horas',
                  case when h.aprobado_por = v_dueno and h.aprobado_el is not null then 'dueño' else coalesce(h.aprobado_por::text, '-') end,
                  coalesce((select v.periodo || '/' || v.horas || '/' || v.reportes from horas_aprobadas_por_obra_periodo v
                             where v.usuario_id = v_equipo and v.proyecto_id = v_obra and v.co = 'C3-CO'), '-'),
                  coalesce((select string_agg(a.accion, '>' order by a.hecho_el) from horas_aprobaciones a where a.horas_id = -3100300),
                           '-'))
      into v_obt
      from horas h
     where h.id = -3100300;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (25, 'horas: el equipo reporta, Edgar aprueba; ni un dólar en el libro', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 26. Un trabajador no se aprueba sus horas, ni teniendo el permiso de
--     corrección de Edgar (42501). Si con ese permiso corrige unas horas
--     que ya estaban APROBADAS, la aprobación se cae sola (lo aprobado ya no
--     es lo que hay) y queda escrito.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_auto   text;
  v_cor    text;
  v_obt    text;
  v_esp    text := 'autoaprobarse=42501 corregir_aprobada=ok aprobacion=se_cayo rastro=aprobada>invalidada';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (26, 'horas: nadie se aprueba solo; corregir lo aprobado tumba la aprobación', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas, correccion_estado)
    values (-3100310, v_desde + 26, v_equipo, v_obra, 8.0, 'c3-pruebas', 'aprobada'),
           (-3100311, v_desde + 27, v_equipo, v_obra, 4.0, 'c3-pruebas', 'aprobada');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 27, v_desde + 27);
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update horas set aprobado_por = v_equipo, aprobado_el = now() where id = -3100310;
      v_auto := case when found then 'entró' else 'no_tocó' end;
    exception when others then
      v_auto := sqlstate;
    end;
    begin
      update horas set horas = 3.5 where id = -3100311;
      v_cor := case when found then 'ok' else 'no_tocó' end;
    exception when others then
      v_cor := sqlstate;
    end;
    execute 'reset role';
    select format('autoaprobarse=%s corregir_aprobada=%s aprobacion=%s rastro=%s', v_auto, v_cor,
                  case when h.aprobado_el is null and h.aprobado_por is null then 'se_cayo' else 'sigue' end,
                  coalesce((select string_agg(a.accion, '>' order by a.hecho_el) from horas_aprobaciones a where a.horas_id = -3100311),
                           '-'))
      into v_obt
      from horas h
     where h.id = -3100311;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (26, 'horas: nadie se aprueba solo; corregir lo aprobado tumba la aprobación', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 27. REGRESIÓN, el flujo de corrección de horas de siempre
--     (trg_guarda_correccion no cambió): sin permiso, el mensaje de
--     siempre; pedir permiso con ✎ ('pedida') entra; con el permiso de Edgar
--     ('aprobada') se corrige UNA vez y el permiso se gasta.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_msg    text := 'Pídele permiso a Edgar para corregir este reporte (toca ✎ y confirma)';
  v_sin    text;
  v_pedir  text;
  v_otra   text;
  v_obt    text;
  v_esp    text;
begin
  v_esp := format('sin_permiso=%1$s pedir=pedida corregir=7.0/- otra_vez=%1$s', v_msg);
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (27, 'regresión: el permiso de corrección de horas funciona igual', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas)
    values (-3100320, v_desde + 26, v_equipo, v_obra, 8.0, 'c3-pruebas');
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update horas set horas = 7.0 where id = -3100320;
      v_sin := 'entró';
    exception when others then
      v_sin := sqlerrm;
    end;
    update horas set correccion_estado = 'pedida' where id = -3100320;
    select h.correccion_estado into v_pedir from horas h where h.id = -3100320;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update horas set correccion_estado = 'aprobada' where id = -3100320;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update horas set horas = 7.0 where id = -3100320;
    begin
      update horas set horas = 6.0 where id = -3100320;
      v_otra := 'entró';
    exception when others then
      v_otra := sqlerrm;
    end;
    execute 'reset role';
    select format('sin_permiso=%s pedir=%s corregir=%s/%s otra_vez=%s', v_sin, v_pedir, h.horas, coalesce(h.correccion_estado, '-'),
                  v_otra)
      into v_obt
      from horas h
     where h.id = -3100320;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (27, 'regresión: el permiso de corrección de horas funciona igual', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 28. El devengo ESTÁNDAR opcional (fn_horas_devengar): Dr 5000 por obra y
--     CO / Cr 2210, por horas APROBADAS × costo por hora; etiquetado
--     estándar, reversible (su reverso automático, el día 1 del mes
--     siguiente, entra con él). Volver a pedirlo con las mismas horas no
--     hace nada, y el control de mano de obra sigue en verde.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_sig    text := nullif(current_setting('mx3.sig', true), '');
  v_mo     text := fn_puente_cuenta_de('mano_obra');
  v_sd     text := fn_puente_cuenta_de('sueldos_devengados');
  v_sigd   date;
  v_r1     jsonb;
  v_r2     jsonb;
  v_as     uuid;
  v_ctl    boolean;
  v_obt    text;
  v_esp    text;
begin
  select p.desde into v_sigd from periodos p where p.periodo = v_sig;
  v_esp := format('accion=posteado linea=%s:240.00:%s:C3-DEV reversible=t auto_reverso=%s estandar=t repetir=sin_cambios control=t',
                  v_mo, v_obra, v_sigd);
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null or v_sig is null then
    insert into _pruebas values (28, 'devengo estándar: reversible, etiquetado, y no se duplica', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra, o el mes abierto y el siguiente', null);
    return;
  end if;
  begin
    insert into costos_equipo (usuario_id, costo_hora) values (v_equipo, 30.00)
    on conflict (usuario_id) do update set costo_hora = 30.00;
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas, co)
    values (-3100330, v_desde + 11, v_equipo, v_obra, 8.0, 'c3-pruebas', 'C3-DEV');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 11, v_desde + 11);
    v_r1 := fn_horas_devengar(v_mes);
    v_r2 := fn_horas_devengar(v_mes);
    execute 'reset role';
    v_as := pg_temp.c3_vivo('horas_devengo', v_mes);
    select c.ok into v_ctl from fn_puentes_verificar() c where c.control = 'mano_de_obra';
    select format('accion=%s linea=%s reversible=%s auto_reverso=%s estandar=%s repetir=%s control=%s',
                  v_r1->>'accion',
                  coalesce((select l.cuenta || ':' || l.monto || ':' || l.proyecto_id || ':' || l.co from asiento_lineas l
                             where l.asiento_id = v_as and l.co = 'C3-DEV'), '-'),
                  a.reversible,
                  (select r.fecha_contable from asientos r where r.reversa_a = v_as and r.camino = 'reverso_automatico'),
                  a.descripcion like '%ESTÁNDAR%' and a.procedencia->>'etiqueta' = 'estándar',
                  v_r2->>'accion', v_ctl)
      into v_obt
      from asientos a
     where a.id = v_as;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (28, 'devengo estándar: reversible, etiquetado, y no se duplica', v_esp, coalesce(v_obt, 'no posteó'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- REGRESIÓN: la app de obra sigue exactamente igual
-- =====================================================================

-- 29. Un trabajador sube un recibo como la app (foto, obra, nota, CO; sin
--     total): entra, espera la lectura, y él lo sigue viendo por
--     recibos_equipo (sin montos), como siempre. Nada en el libro.
do $$
declare
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_ins    text;
  v_ve     bigint;
  v_tabla  bigint;
  v_obt    text;
  v_esp    text;
begin
  -- Sin fecha, cuenta el día en que se subió (hoy): antes del corte, ni
  -- espera (vive en QuickBooks); desde el corte, espera la lectura.
  v_esp := format('subir=ok estado=por_leer puente=%s ve_en_recibos_equipo=1 ve_la_tabla=0 asientos=0/0',
                  case when fn_fecha_miami(now()) >= fn_puente_corte() then 'espera/por_leer' else 'no_aplica/antes_del_corte' end);
  if v_equipo is null or v_obra is null then
    insert into _pruebas values (29, 'regresión: el equipo sube un recibo como siempre', v_esp, 'omitida: falta alguien del equipo u obra', null);
    return;
  end if;
  begin
    perform pg_temp.c3_inmediato();
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      insert into recibos (id, proyecto_id, ruta, notas, co, autor_id)
      values (-3100400, v_obra, 'recibos/c3-pruebas/400.jpg', 'c3-pruebas: cable y cajas', 'CO-2', v_equipo);
      v_ins := 'ok';
    exception when others then
      v_ins := sqlstate;
    end;
    select count(*) into v_ve from recibos_equipo where id = -3100400;
    select count(*) into v_tabla from recibos where id = -3100400;
    execute 'reset role';
    select format('subir=%s estado=%s puente=%s ve_en_recibos_equipo=%s ve_la_tabla=%s asientos=%s', v_ins,
                  coalesce((select r.estado from recibos r where r.id = -3100400), '-'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3100400'), '-'),
                  v_ve, v_tabla, pg_temp.c3_cuantos('recibos', '-3100400'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (29, 'regresión: el equipo sube un recibo como siempre', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 30. Edgar, desde la app, ANTES de que el recibo entre al libro: lo lee, le
--     pone el total con ✎ (entra), le asigna obra con 📌 a uno que no tenía
--     (entra), le pone la foto con 📷 a uno «sin_foto» (entra) y borra uno
--     que no va (se borra, como siempre).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_lee   bigint;
  v_borra bigint;
  v_antes text;
  v_obt   text;
  v_esp   text := 'lee=1 lapiz=espera/por_leer→contabilizado chincheta=pendiente/sin_obra→contabilizado '
                  'camara=pendiente/sin_foto→contabilizado borrar=1';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (30, 'regresión: Edgar lee, corrige (✎), asigna (📌), pone foto (📷) y borra', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    -- Lo que la lectura ya llenó, menos el total (✎); uno sin obra (📌);
    -- uno sin foto (📷); uno por leer que no va.
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100401, 'estado', 'por_leer', 'total', null));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100402, 'total', '52.10', 'proyecto_id', null));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100403, 'estado', 'sin_foto', 'total', '19.95', 'ruta', null));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100404, 'estado', 'por_leer', 'total', null));
    select string_agg(d.documento_id || '=' || d.estado || '/' || d.codigo, ' ' order by d.documento_id) into v_antes
      from puente_documentos d where d.tabla = 'recibos' and d.documento_id in ('-3100401', '-3100402', '-3100403');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select count(*) into v_lee from recibos where id = -3100401 and total is null;
    update recibos set proveedor = 'C3 PRUEBAS SUPPLY', notas = 'c3-pruebas: breakers', total = 342.18, estado = 'leido'
     where id = -3100401;
    update recibos set proyecto_id = v_obra where id = -3100402;
    update recibos set ruta = 'recibos/c3-pruebas/403.jpg', estado = 'leido' where id = -3100403;
    delete from recibos where id = -3100404;
    get diagnostics v_borra = row_count;
    execute 'reset role';
    select format('lee=%s lapiz=%s→%s chincheta=%s→%s camara=%s→%s borrar=%s', v_lee,
                  substring(v_antes from '-3100401=(\S+)'),
                  (select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100401'),
                  substring(v_antes from '-3100402=(\S+)'),
                  (select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100402'),
                  substring(v_antes from '-3100403=(\S+)'),
                  (select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3100403'),
                  v_borra)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (30, 'regresión: Edgar lee, corrige (✎), asigna (📌), pone foto (📷) y borra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 31. REGRESIÓN, el trigger de materiales: un recibo cuya nota nombra un
--     material que falta lo marca «comprado» (con su recibo); al anular el
--     recibo, vuelve a «falta». Igual que antes de los puentes.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_quien  uuid := coalesce(nullif(current_setting('mx3.equipo', true), '')::uuid, nullif(current_setting('mx3.dueno', true), '')::uuid);
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_subir  text;
  v_obt    text;
  v_esp    text := 'al_subir=comprado/-3100411 al_anular=falta/-';
begin
  if v_dueno is null or v_obra is null then
    insert into _pruebas values (31, 'regresión: el recibo marca el material comprado, y al anularlo vuelve a falta', v_esp,
                                 'omitida: falta dueño u obra', null);
    return;
  end if;
  begin
    perform pg_temp.c3_inmediato();
    insert into materiales (id, proyecto_id, descripcion, cantidad, estado, autor_id)
    values (-3100410, v_obra, 'C3 BREAKER 20A GE', '4', 'falta', v_dueno);
    perform set_config('request.jwt.claims', json_build_object('sub', v_quien, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    insert into recibos (id, proyecto_id, ruta, notas, autor_id)
    values (-3100411, v_obra, 'recibos/c3-pruebas/411.jpg', 'compré c3 breaker 20a ge x4 y cinta', v_quien);
    execute 'reset role';
    select m.estado || '/' || coalesce(m.recibo_id::text, '-') into v_subir from materiales m where m.id = -3100410;
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_recibo_anular(-3100411, 'c3: no era de esta obra');
    execute 'reset role';
    select format('al_subir=%s al_anular=%s/%s', v_subir, m.estado, coalesce(m.recibo_id::text, '-'))
      into v_obt
      from materiales m
     where m.id = -3100410;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (31, 'regresión: el recibo marca el material comprado, y al anularlo vuelve a falta', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 32. La lectura de cerebro (service_role), en varios pasos dentro de la
--     misma transacción: el puente es diferido y corre al confirmar, con el
--     papel ya completo. Entra UNA vez, sin reversos de paso, con el rol de
--     quien escribió (service_role).
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mat   text := current_setting('mx3.material', true);
  v_inm   text;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('asientos=1/0 camino=puente rol=service_role lineas=%s:312.40:%s:CO-3:-:- | 2100-9998:-312.40:-:-:-:-', v_mat, v_obra);
  if v_obra is null or v_desde is null then
    insert into _pruebas values (32, 'la lectura de cerebro en varios pasos entra una vez', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    v_inm := pg_temp.c3_inmediato_sql();
    -- Subido por la app, por leer (el puente todavía no corre: diferido).
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100420, 'estado', 'por_leer', 'total', null, 'fecha', null,
                                                 'metodo_pago', null, 'ultimos4', null, 'proveedor', null, 'categoria', 'material',
                                                 'creado', ((v_desde + 4) + time '12:00')::text));
    perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
    execute 'set local role service_role';
    update recibos set total = 312.40, subtotal = 291.96, tax = 20.44, fecha = v_desde + 4, proveedor = 'C3 PRUEBAS SUPPLY',
                       num_recibo = 'T-420', estado = 'leido'
     where id = -3100420;
    update recibos set categoria = 'c3 pruebas material', metodo_pago = 'c3 pruebas tarjeta', ultimos4 = '9998', co = 'CO-3'
     where id = -3100420;
    -- «Confirmar» con el rol de cerebro puesto: corren los puentes pendientes.
    execute v_inm;
    execute 'reset role';
    select format('asientos=%s camino=%s rol=%s lineas=%s', pg_temp.c3_cuantos('recibos', '-3100420'), a.camino, a.rol_bd,
                  pg_temp.c3_lineas(a.id))
      into v_obt
      from asientos a
     where a.id = pg_temp.c3_vivo('recibos', '-3100420');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (32, 'la lectura de cerebro en varios pasos entra una vez', v_esp, coalesce(v_obt, 'no posteó'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- Quién puede qué
-- =====================================================================

-- 33. contabilizado_en solo lo pone el puente (ni Edgar desde la app ni el
--     SQL Editor); un trabajador no llama a las funciones de Edgar (42501);
--     la llave pública (anon) no ejecuta ninguna función de los puentes y
--     nadie de la API las internas; el equipo no ve nada de las tablas
--     nuevas y anon ni puede leerlas.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_as     uuid;
  v_a1     text;
  v_a2     text;
  v_a3     text;
  v_eq     text := '';
  v_ve     bigint;
  v_anon   text;
  v_fn     text;
  v_obt    text;
  v_esp    text := 'contabilizado_en=MX003/MX003/MX003 equipo=42501,42501,42501,42501,42501 anon_ejecuta=0 internas_api=0 equipo_ve=0 anon_lee=42501';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (33, 'quién puede qué: contabilizado_en, funciones de Edgar, anon, tablas nuevas', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100430, 'total', '33.00'));
    v_as := pg_temp.c3_vivo('recibos', '-3100430');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update recibos set contabilizado_en = null where id = -3100430;
      v_a1 := case when found then 'entró' else 'no_tocó' end;
    exception when others then
      v_a1 := sqlstate;
    end;
    begin
      insert into recibos (id, proyecto_id, ruta, notas, autor_id, contabilizado_en)
      values (-3100431, v_obra, 'recibos/c3-pruebas/431.jpg', 'c3-pruebas', v_dueno, v_as);
      v_a2 := 'entró';
    exception when others then
      v_a2 := sqlstate;
    end;
    execute 'reset role';
    begin
      update recibos set contabilizado_en = null where id = -3100430;
      v_a3 := case when found then 'entró' else 'no_tocó' end;
    exception when others then
      v_a3 := sqlstate;
    end;
    -- El trabajador y las funciones de Edgar.
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    foreach v_fn in array array['select public.fn_mapeo_categoria(''c3 x'', ''5100'')',
                                'select public.fn_puentes_correr()',
                                'select public.fn_cobro_registrar(''{}''::jsonb)',
                                format('select public.fn_horas_aprobar(%L::uuid, %L::date, %L::date)', v_equipo, v_desde, v_desde),
                                'select public.fn_recibo_anular(-3100430, ''c3'')'] loop
      begin
        execute v_fn;
        v_eq := v_eq || ',entró';
      exception when others then
        v_eq := v_eq || ',' || sqlstate;
      end;
    end loop;
    select (select count(*) from cobros) + (select count(*) from aplicaciones_cobro) + (select count(*) from notas_credito)
         + (select count(*) from puente_documentos) + (select count(*) from proveedores) + (select count(*) from tarjetas)
         + (select count(*) from mapeo_metodo_pago) + (select count(*) from mapeo_categoria_recibo)
         + (select count(*) from puente_reglas_historial) + (select count(*) from horas_aprobaciones)
         + (select count(*) from puentes_bandeja) + (select count(*) from cxp_abierta) + (select count(*) from cxc_abierta)
         + (select count(*) from facturas_cobro)
      into v_ve;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    begin
      perform count(*) from public.cobros;
      v_anon := 'entró';
    exception when others then
      v_anon := sqlstate;
    end;
    execute 'reset role';
    select format('contabilizado_en=%s/%s/%s equipo=%s anon_ejecuta=%s internas_api=%s equipo_ve=%s anon_lee=%s', v_a1, v_a2, v_a3,
                  substr(v_eq, 2),
                  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public'
                      and (p.proname like 'fn\_puente%' or p.proname in ('fn_factura_anular', 'fn_cobro_registrar', 'fn_cobro_anular',
                            'fn_anticipo_aplicar', 'fn_horas_aprobar', 'fn_horas_desaprobar', 'fn_horas_devengar', 'fn_recibo_anular',
                            'fn_externo_anular', 'fn_mapeo_categoria', 'fn_mapeo_metodo_pago', 'fn_mapeo_tipo_proyecto',
                            'fn_mapeo_confirmar', 'fn_tarjeta_alta', 'fn_proveedor_alta', 'fn_proveedor_alias'))
                      and has_function_privilege('anon', p.oid, 'execute')),
                  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public' and p.proname like 'fn\_puente\_%'
                      and (has_function_privilege('anon', p.oid, 'execute')
                           or has_function_privilege('authenticated', p.oid, 'execute')
                           or has_function_privilege('service_role', p.oid, 'execute'))),
                  v_ve, v_anon)
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (33, 'quién puede qué: contabilizado_en, funciones de Edgar, anon, tablas nuevas', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 34. Nunca a 2300 (use tax) desde un recibo: ni una categoría, ni una
--     forma de pago «banco», ni una tarjeta pueden apuntar ahí (MX004), y el
--     control use_tax sigue en verde.
do $$
declare
  v_ut  text := fn_puente_cuenta_de('use_tax');
  v_c   text;
  v_b   text;
  v_t   text;
  v_ctl boolean;
  v_obt text;
  v_esp text := 'categoria=MX004 banco=MX004 tarjeta=MX004 control_use_tax=t';
begin
  if v_ut is null then
    insert into _pruebas values (34, 'nunca a 2300 desde un recibo', v_esp, 'omitida: no hay cuenta de use tax en puente_cuentas', null);
    return;
  end if;
  begin
    begin
      perform fn_mapeo_categoria('c3 pruebas impuesto', v_ut);
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
    end;
    begin
      perform fn_mapeo_metodo_pago('c3 pruebas impuesto', 'banco', v_ut);
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    begin
      perform fn_tarjeta_alta('9997', v_ut, 'c3-pruebas');
      v_t := 'entró';
    exception when others then
      v_t := sqlstate;
    end;
    select c.ok into v_ctl from fn_puentes_verificar() c where c.control = 'use_tax';
    v_obt := format('categoria=%s banco=%s tarjeta=%s control_use_tax=%s', v_c, v_b, v_t,
                    case when v_ctl then 't' when not v_ctl then 'f' else '-' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (34, 'nunca a 2300 desde un recibo', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 35. Un trabajo externo contabilizado: corregir su costo deja reverso +
--     sustituto; borrarlo, NO (MX003, que dice cómo se anula); anularlo con
--     fn_externo_anular deja el costo en 0, lo reversa con el motivo, y el
--     papel se queda.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_ed    text;
  v_bo    text;
  v_msg   text;
  v_obt   text;
  v_esp   text := 'editar=3/1:350.00 borrar=MX003/dice_como anular=4/2:no_aplica/costo_cero motivo=t papel=0';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (35, 'trabajo externo: se corrige y se anula; no se borra', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, externo_id) overriding system value
    values (-3100440, v_obra, 'c3-pruebas: ayudante', v_desde + 2, 'horas', 16, 320.00, -3900001);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update trabajos_externos set costo = 350.00 where id = -3100440;
    execute 'reset role';
    v_ed := pg_temp.c3_cuantos('trabajos_externos', '-3100440') || ':'
            || coalesce((select l.monto::text from asiento_lineas l
                          where l.asiento_id = pg_temp.c3_vivo('trabajos_externos', '-3100440') and l.monto > 0), '-');
    execute 'set local role authenticated';
    begin
      delete from trabajos_externos where id = -3100440;
      v_bo := 'entró';
    exception when others then
      v_bo := sqlstate;
      v_msg := sqlerrm;
    end;
    perform fn_externo_anular(-3100440, 'c3: el ayudante no vino');
    execute 'reset role';
    select format('editar=%s borrar=%s anular=%s:%s motivo=%s papel=%s', v_ed,
                  v_bo || case when v_msg like '%fn_externo_anular%' then '/dice_como' else '' end,
                  pg_temp.c3_cuantos('trabajos_externos', '-3100440'),
                  (select d.estado || '/' || d.codigo from puente_documentos d
                    where d.tabla = 'trabajos_externos' and d.documento_id = '-3100440'),
                  exists (select 1 from asientos a where a.origen_tabla = 'trabajos_externos' and a.origen_id = '-3100440'
                                                    and a.camino = 'reverso' and a.motivo like '%Motivo de Edgar: c3: el ayudante no vino%'),
                  x.costo)
      into v_obt
      from trabajos_externos x
     where x.id = -3100440;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (35, 'trabajo externo: se corrige y se anula; no se borra', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;


-- =====================================================================
-- Reglas, obras, controles
-- =====================================================================

-- 36. Una regla que cambia NO rehace lo ya contabilizado (ni con el
--     backfill): el asiento se queda con la cuenta con que entró, y el
--     cambio queda en el historial de la regla. Rehacerlo es a propósito,
--     papel por papel, con su motivo (fn_puentes_rehacer): reverso + asiento
--     nuevo con la regla de hoy, enlazados.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mat   text := current_setting('mx3.material', true);
  v_otra  text;
  v_orig  uuid;
  v_nuevo uuid;
  v_1     text;
  v_2     text;
  v_obt   text;
  v_esp   text;
begin
  select c.codigo into v_otra from cuentas c
   where c.tipo = 'costo' and c.regla_obra = 'obligatoria' and c.activa and c.imputable
     and c.codigo <> v_mat
     and c.codigo not in (select pc.cuenta from puente_cuentas pc where pc.rol in ('mano_obra', 'mano_obra_oficial', 'subcontratos'))
   order by (c.codigo = '5300') desc, c.codigo
   limit 1;
  v_esp := format('tras_cambiar_regla=%1$s tras_correr=%1$s rehecho=%2$s enlazado=t motivo=t historial=t', v_mat, v_otra);
  if v_dueno is null or v_obra is null or v_desde is null or v_otra is null then
    insert into _pruebas values (36, 'una regla nueva no rehace lo contabilizado; fn_puentes_rehacer sí, con motivo', v_esp,
                                 'omitida: falta dueño, obra, mes abierto u otra cuenta de costo', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100450, 'total', '80.00'));
    v_orig := pg_temp.c3_vivo('recibos', '-3100450');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_mapeo_categoria('c3 pruebas material', v_otra);
    execute 'reset role';
    select l.cuenta into v_1 from asiento_lineas l where l.asiento_id = pg_temp.c3_vivo('recibos', '-3100450') and l.monto > 0;
    execute 'set local role authenticated';
    perform fn_puentes_correr();
    execute 'reset role';
    select l.cuenta into v_2 from asiento_lineas l where l.asiento_id = pg_temp.c3_vivo('recibos', '-3100450') and l.monto > 0;
    execute 'set local role authenticated';
    perform fn_puentes_rehacer('recibos', '-3100450', 'c3: la regla del material estaba mal');
    execute 'reset role';
    v_nuevo := pg_temp.c3_vivo('recibos', '-3100450');
    select format('tras_cambiar_regla=%s tras_correr=%s rehecho=%s enlazado=%s motivo=%s historial=%s', coalesce(v_1, '-'),
                  coalesce(v_2, '-'),
                  coalesce((select l.cuenta from asiento_lineas l where l.asiento_id = v_nuevo and l.monto > 0), '-'),
                  coalesce((select a.sustituye_a = v_orig from asientos a where a.id = v_nuevo), false),
                  exists (select 1 from asientos r
                           where r.reversa_a = v_orig and r.camino = 'reverso'
                             and r.motivo like 'Rehecho con las reglas de hoy%Motivo de Edgar: c3: la regla del material estaba mal'),
                  exists (select 1 from puente_reglas_historial h
                           where h.tabla = 'mapeo_categoria_recibo' and h.clave = 'c3 pruebas material' and h.operacion = 'UPDATE'
                             and h.despues->>'cuenta' = v_otra and h.antes->>'cuenta' = v_mat))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (36, 'una regla nueva no rehace lo contabilizado; fn_puentes_rehacer sí, con motivo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 37. Una obra con papeles en el libro no se borra (su borrado arrastraría
--     los papeles), aunque sus líneas no lleven la obra (la gasolina): MX003,
--     que dice qué hacer (marcarla Completado).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_b     text;
  v_msg   text;
  v_obt   text;
  v_esp   text := 'borrar_obra=MX003/dice_que_hacer';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (37, 'una obra con papeles en el libro no se borra', v_esp, 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100460, 'total', '45.00', 'categoria', 'c3 pruebas gasolina'));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      delete from proyectos where id = v_obra;
      v_b := case when found then 'entró' else 'no_tocó' end;
    exception when others then
      v_b := sqlstate;
      v_msg := sqlerrm;
    end;
    execute 'reset role';
    v_obt := 'borrar_obra=' || v_b || case when v_msg like '%Completado%' then '/dice_que_hacer' else '' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (37, 'una obra con papeles en el libro no se borra', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 38. Una categoría cuya cuenta NO va por obra (la gasolina, 6300: gasto
--     general): el recibo entra sin obra en la línea aunque la traiga, y la
--     obra queda escrita en la nota de la línea y en la procedencia.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_veh   text := nullif(current_setting('mx3.vehiculo', true), '');
  v_as    uuid;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('lineas=%s:25.00:-:-:-:- | 2100-9998:-25.00:-:-:-:- obra_en_la_nota=t nota=t', v_veh);
  if v_obra is null or v_desde is null or v_veh is null then
    insert into _pruebas values (38, 'una cuenta sin obra (gasolina): la obra queda en la nota', v_esp,
                                 'omitida: falta obra, mes abierto o una cuenta de gasto sin obra', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100470, 'total', '25.00', 'categoria', 'c3 pruebas gasolina',
                                                 'proveedor', 'C3 PRUEBAS GAS'));
    v_as := pg_temp.c3_vivo('recibos', '-3100470');
    select format('lineas=%s obra_en_la_nota=%s nota=%s', pg_temp.c3_lineas(v_as),
                  exists (select 1 from asiento_lineas l where l.asiento_id = v_as and l.monto > 0 and l.memo like '%obra ' || v_obra || '%'),
                  coalesce((select a.procedencia->>'notas' like '%no va por obra%' from asientos a where a.id = v_as), false))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (38, 'una cuenta sin obra (gasolina): la obra queda en la nota', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 39. Si alguien APAGA el puente y edita un recibo por debajo, el libro no
--     se entera... pero el control sí: fn_puentes_verificar marca el trigger
--     apagado y el papel que ya no es lo que se contabilizó. Encendido otra
--     vez, el backfill lo pone al día (reverso + sustituto) y el control
--     vuelve a verde.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_trig  text;
  v_doc   text;
  v_doc2  text;
  v_omite text;
  v_obt   text;
  v_esp   text := 'apagado: triggers=f documentos=f/cambio_por_debajo backfill: documentos=t asientos=3/1';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (39, 'el puente apagado se detecta, y el backfill lo pone al día', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100480, 'total', '90.00'));
    if exists (select 1 from pg_trigger where tgname = 'trg_puente_recibos_despues') then
      -- Si la app está usando recibos, no se la hace esperar: omitida.
      execute 'set local lock_timeout = ''2s''';
      begin
        execute 'alter table public.recibos disable trigger trg_puente_recibos_despues';
      exception when lock_not_available then
        v_omite := 'la tabla recibos estaba en uso (se prueba en el banco)';
        raise exception using errcode = 'MXT00';
      end;
    end if;
    update recibos set total = 95.00 where id = -3100480;
    select case bool_and(c.ok) when true then 't' when false then 'f' else '-' end into v_trig
      from fn_puentes_verificar() c where c.control = 'triggers';
    select case bool_and(c.ok) when true then 't' when false then 'f' else '-' end
           || case when bool_or(c.detalle::text like '%recibos -3100480 cambió por debajo de su puente%') then '/cambio_por_debajo' else '' end
      into v_doc
      from fn_puentes_verificar() c where c.control = 'documentos';
    if exists (select 1 from pg_trigger where tgname = 'trg_puente_recibos_despues') then
      execute 'alter table public.recibos enable trigger trg_puente_recibos_despues';
    end if;
    perform fn_puentes_correr();
    select case bool_and(c.ok) when true then 't' when false then 'f' else '-' end into v_doc2
      from fn_puentes_verificar() c where c.control = 'documentos';
    v_obt := format('apagado: triggers=%s documentos=%s backfill: documentos=%s asientos=%s', v_trig, v_doc, v_doc2,
                    pg_temp.c3_cuantos('recibos', '-3100480'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  if v_omite is not null then
    insert into _pruebas values (39, 'el puente apagado se detecta, y el backfill lo pone al día', v_esp, 'omitida: ' || v_omite, null);
  else
    insert into _pruebas values (39, 'el puente apagado se detecta, y el backfill lo pone al día', v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 40. Después de una mezcla de todo (recibos que entran, se corrigen y se
--     anulan, una factura con retención y su cobro, un trabajo externo), al
--     confirmar: la cadena del libro entera en verde (sus diez controles) y
--     los controles de los puentes.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_libro  text;
  v_puente text;
  v_obt    text;
  v_esp    text := 'libro=t puentes=documentos:t mano_de_obra:t reglas:t triggers:t use_tax:t';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (40, 'al confirmar una mezcla de todo: libro y puentes en verde', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100490, 'total', '10.00'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100491, 'total', '20.00', 'metodo_pago', 'c3 pruebas cuenta', 'ultimos4', null));
    update recibos set total = 11.00 where id = -3100490;
    update recibos set estado = 'anulado' where id = -3100491;
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3100492, v_obra, 'C3-492', v_desde + 2, 1000.00, 100.00);
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo) overriding system value
    values (-3100493, v_obra, 'c3-pruebas: subcontrato sin ayudante enlazado', v_desde + 2, 'ajuste', null, 100.00);
    perform fn_cobro_registrar(jsonb_build_object(
              'fecha', (v_desde + 9)::text, 'monto', '450.00', 'medio', 'cheque',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100492, 'monto', '450.00'))));
    set constraints all immediate;   -- lo que hace el commit
    select case when bool_and(v.ok) then 't' else 'f: ' || string_agg(v.control, ',') filter (where not v.ok) end
      into v_libro from fn_verificar_cadena() v;
    select string_agg(c.control || ':' || case when c.ok then 't' else 'f' end, ' ' order by c.control) into v_puente
      from fn_puentes_verificar() c
     where c.control in ('triggers', 'documentos', 'reglas', 'use_tax', 'mano_de_obra');
    v_obt := format('libro=%s puentes=%s', v_libro, coalesce(v_puente, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (40, 'al confirmar una mezcla de todo: libro y puentes en verde', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 41. Un trabajador no puede meter por la API un recibo ya «leído», con el
--     monto y la forma de pago que quiera (el puente lo contabilizaría: una
--     deuda a un supply, un reembolso a su nombre): 42501. Por la app sube
--     como siempre (prueba 29).
do $$
declare
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_1      text;
  v_2      text;
  v_obt    text;
  v_esp    text := 'leido_con_monto=42501 reembolso_a_si_mismo=42501 asientos=0';
begin
  if v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (41, 'el equipo no mete un recibo ya leído con su monto', v_esp,
                                 'omitida: falta alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      insert into recibos (id, proyecto_id, ruta, notas, autor_id, total, estado, fecha, categoria, metodo_pago, proveedor)
      values (-3100610, v_obra, 'recibos/c3-pruebas/610.jpg', 'c3-pruebas', v_equipo, 5000.00, 'leido', v_desde + 4,
              'c3 pruebas material', 'c3 pruebas cuenta', 'C3 PRUEBAS SUPPLY');
      v_1 := 'entró';
    exception when others then
      v_1 := sqlstate;
    end;
    begin
      insert into recibos (id, proyecto_id, ruta, notas, autor_id, total, estado, metodo_pago)
      values (-3100611, v_obra, 'recibos/c3-pruebas/611.jpg', 'c3-pruebas', v_equipo, 900.00, 'leido', 'c3 pruebas reembolso');
      v_2 := 'entró';
    exception when others then
      v_2 := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('leido_con_monto=%s reembolso_a_si_mismo=%s asientos=%s', v_1, v_2,
                    (select count(*) from asientos where origen_tabla = 'recibos' and origen_id in ('-3100610', '-3100611')));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (41, 'el equipo no mete un recibo ya leído con su monto', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 42. Ningún puente de papel carga a MANO DE OBRA (el bloque 50xx: 5000,
--     5001 y su burden): una categoría de recibo no puede apuntar ahí, ni la
--     cuenta de subcontratos de los puentes (MX004). Los dólares de mano de
--     obra solo salen de la nómina (f11) o del devengo estándar.
do $$
declare
  v_mo  text := fn_puente_cuenta_de('mano_obra');
  v_bu  text;
  v_1   text;
  v_2   text;
  v_3   text;
  v_obt text;
  v_esp text := 'categoria_mano_de_obra=MX004 categoria_burden=MX004 subcontratos_a_mano_de_obra=MX004';
begin
  select c.codigo into v_bu from cuentas c
   where left(c.codigo, 2) = '50' and c.tipo = 'costo' and c.activa and c.imputable and c.regla_obra = 'obligatoria'
     and c.codigo not in (select pc.cuenta from puente_cuentas pc where pc.rol in ('mano_obra', 'mano_obra_oficial'))
   order by c.codigo
   limit 1;
  if v_mo is null or v_bu is null then
    insert into _pruebas values (42, 'ningún puente de papel carga a mano de obra', v_esp,
                                 'omitida: el plan no tiene la cuenta de mano de obra o la de burden', null);
    return;
  end if;
  begin
    begin
      perform fn_mapeo_categoria('c3 pruebas jornal', v_mo);
      v_1 := 'entró';
    exception when others then
      v_1 := sqlstate;
    end;
    begin
      perform fn_mapeo_categoria('c3 pruebas burden', v_bu);
      v_2 := 'entró';
    exception when others then
      v_2 := sqlstate;
    end;
    begin
      perform fn_puentes_cuenta('subcontratos', v_mo);
      v_3 := 'entró';
    exception when others then
      v_3 := sqlstate;
    end;
    v_obt := format('categoria_mano_de_obra=%s categoria_burden=%s subcontratos_a_mano_de_obra=%s', v_1, v_2, v_3);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (42, 'ningún puente de papel carga a mano de obra', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 43. El mismo dinero no entra dos veces cuando llegue el banco (f06): un
--     movimiento del banco casa con UN solo cobro vigente (el segundo,
--     MX008, en español); un cobro registrado a mano se casa después con su
--     movimiento, una vez, y eso ya no cambia (MX003).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_r     jsonb;
  v_2     text;
  v_casar text;
  v_camb  text;
  v_obt   text;
  v_esp   text := 'mismo_movimiento=MX008 casar=ok cambiar=MX003';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (43, 'un movimiento del banco casa con un solo cobro', v_esp, 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100620, v_obra, 'C3-620', v_desde + 2, 1000.00);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cobro_registrar(jsonb_build_object(
              'fecha', (v_desde + 8)::text, 'monto', '400.00', 'medio', 'ach', 'movimiento_id', 'c3-pruebas-mov-1',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100620, 'monto', '400.00'))));
    begin
      perform fn_cobro_registrar(jsonb_build_object(
                'fecha', (v_desde + 8)::text, 'monto', '300.00', 'medio', 'ach', 'movimiento_id', 'c3-pruebas-mov-1',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100620, 'monto', '300.00'))));
      v_2 := 'entró';
    exception when others then
      v_2 := sqlstate;
    end;
    v_r := fn_cobro_registrar(jsonb_build_object(
             'fecha', (v_desde + 9)::text, 'monto', '100.00', 'medio', 'cheque',
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3100620, 'monto', '100.00'))));
    execute 'reset role';
    begin
      update cobros set movimiento_id = 'c3-pruebas-mov-2' where id = (v_r->>'cobro')::uuid;
      v_casar := case when found then 'ok' else 'no_tocó' end;
    exception when others then
      v_casar := sqlstate;
    end;
    begin
      update cobros set movimiento_id = 'c3-pruebas-mov-3' where id = (v_r->>'cobro')::uuid;
      v_camb := 'entró';
    exception when others then
      v_camb := sqlstate;
    end;
    v_obt := format('mismo_movimiento=%s casar=%s cambiar=%s', v_2, v_casar, v_camb);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (43, 'un movimiento del banco casa con un solo cobro', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 44. Nada queda en un limbo: una factura sin monto, una sin obra, una de
--     una obra cuyo tipo no tiene cuenta de ingreso y un recibo con una
--     categoría que nadie ha visto no postean, y los cuatro están en la
--     bandeja con su motivo.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_obt   text;
  v_esp   text := 'bandeja=-3100600:sin_monto -3100601:sin_obra -3100602:tipo_proyecto -3100603:categoria con_motivo=4 asientos=0';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (44, 'nada queda en un limbo: lo que no postea está en la bandeja', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    -- El tipo de la obra se queda sin cuenta de ingreso (solo aquí adentro).
    delete from mapeo_tipo_proyecto where tipo = fn_puente_normalizar(v_f->>'tipo');
    insert into facturas (id, proyecto_id, num, fecha, monto) overriding system value
    values (-3100600, v_obra, 'C3-600', v_desde + 2, null),
           (-3100601, null, 'C3-601', v_desde + 2, 100.00),
           (-3100602, v_obra, 'C3-602', v_desde + 2, 100.00);
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100603, 'total', '15.00', 'categoria', 'c3 algo que nadie ha visto'));
    select format('bandeja=%s con_motivo=%s asientos=%s',
                  coalesce(string_agg(b.documento_id || ':' || b.codigo, ' ' order by b.documento_id), '-'),
                  count(*) filter (where coalesce(btrim(b.motivo), '') <> ''),
                  (select count(*) from asientos a
                    where (a.origen_tabla, a.origen_id) in (('facturas', '-3100600'), ('facturas', '-3100601'), ('facturas', '-3100602'),
                                                            ('recibos', '-3100603'))))
      into v_obt
      from puentes_bandeja b
     where b.documento_id in ('-3100600', '-3100601', '-3100602', '-3100603');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (44, 'nada queda en un limbo: lo que no postea está en la bandeja', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 45. El papel no se borra en Storage: la foto de un recibo (recibos/…) y
--     un documento del dueño (docs/…) no se borran por la API, ni siquiera
--     Edgar (la policy restrictiva se suma a la suya); una foto de obra
--     (otra carpeta) se borra como hoy. Sin Storage en la base, omitida.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_omite text;
  v_1     bigint;
  v_2     bigint;
  v_3     bigint;
  v_ctl   text;
  v_obt   text;
  v_esp   text := 'recibo=0 documento=0 foto_de_obra=1 control=t';
begin
  if to_regclass('storage.objects') is null or v_dueno is null or v_obra is null then
    insert into _pruebas values (45, 'el papel no se borra en Storage', v_esp,
                                 'omitida: no hay Storage en esta base (en el banco: 03-storage-simulacro.sql)', null);
    return;
  end if;
  begin
    begin
      execute 'insert into storage.objects (bucket_id, name, owner) values ($1, $2, $4), ($1, $3, $4), ($1, $5, $4)'
        using 'fotos', 'recibos/c3-pruebas/450.jpg', 'docs/c3-pruebas/450.pdf', v_dueno, v_obra || '/c3-pruebas-450.jpg';
    exception when others then
      v_omite := format('no se pudo simular un archivo en Storage (%s): %s', sqlstate, left(sqlerrm, 80));
    end;
    if v_omite is null then
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      begin
        execute 'delete from storage.objects where bucket_id = $1 and name = $2' using 'fotos', v_obra || '/c3-pruebas-450.jpg';
        get diagnostics v_3 = row_count;
      exception when others then
        v_omite := format('esta base no deja borrar de Storage por SQL (%s): se prueba en el banco', sqlstate);
      end;
      if v_omite is null then
        execute 'delete from storage.objects where bucket_id = $1 and name = $2' using 'fotos', 'recibos/c3-pruebas/450.jpg';
        get diagnostics v_1 = row_count;
        execute 'delete from storage.objects where bucket_id = $1 and name = $2' using 'fotos', 'docs/c3-pruebas/450.pdf';
        get diagnostics v_2 = row_count;
      end if;
      execute 'reset role';
    end if;
    select case bool_and(c.ok) when true then 't' when false then 'f' else '-' end into v_ctl
      from fn_puentes_verificar() c where c.control = 'papel';
    v_obt := format('recibo=%s documento=%s foto_de_obra=%s control=%s', v_1, v_2, v_3, v_ctl);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  if v_omite is not null then
    insert into _pruebas values (45, 'el papel no se borra en Storage', v_esp, 'omitida: ' || v_omite, null);
  else
    insert into _pruebas values (45, 'el papel no se borra en Storage', v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 46. Un proveedor con movimientos en el libro (el tercero de su CxP) no
--     se borra: MX003, que dice que se marca inactivo. Uno sin movimientos
--     se borra como cualquier regla.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_otro  uuid;
  v_1     text;
  v_msg   text;
  v_2     text;
  v_obt   text;
  v_esp   text := 'con_movimientos=MX003/dice_que_hacer sin_movimientos=borrado';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (46, 'un proveedor con movimientos en el libro no se borra', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3100630, 'total', '70.00', 'metodo_pago', 'c3 pruebas cuenta',
                                                 'ultimos4', null));
    v_otro := fn_proveedor_alta('C3 PRUEBAS OTRO SUPPLY', null, '{}');
    begin
      delete from proveedores_alias where proveedor_id = (v_f->>'proveedor')::uuid;
      delete from proveedores where id = (v_f->>'proveedor')::uuid;
      v_1 := 'entró';
    exception when others then
      v_1 := sqlstate;
      v_msg := sqlerrm;
    end;
    begin
      delete from proveedores_alias where proveedor_id = v_otro;
      delete from proveedores where id = v_otro;
      v_2 := case when found then 'borrado' else 'no_borró' end;
    exception when others then
      v_2 := sqlstate;
    end;
    v_obt := format('con_movimientos=%s sin_movimientos=%s',
                    v_1 || case when v_msg like '%inactivo%' then '/dice_que_hacer' else '' end, v_2);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (46, 'un proveedor con movimientos en el libro no se borra', v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- Ronda de arreglos (24-sep): cada prueba de aquí abajo habría fallado
-- con la versión anterior de c3-puentes.sql.
-- =====================================================================

-- 47. REGRESIÓN, el trigger de materiales y la escritura del puente: un
--     material nuevo en «falta» cuya descripción sale en las notas de un
--     recibo YA contabilizado sigue en «falta» cuando el puente vuelve a
--     escribir el asiento vivo del recibo (rehacer, reintentar): nadie lo
--     compró. (Antes, trg_recibo_marca_material corría con cualquier update
--     del recibo, también con el del puente, y se lo llevaba.)
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_r     jsonb;
  v_obt   text;
  v_esp   text := 'rehacer=sustituido material=falta/-';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (47, 'materiales: la escritura del puente no marca comprado un material nuevo', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200001, 'total', '120.00', 'notas', 'c3 cable thhn 12 rollo'));
    insert into materiales (id, proyecto_id, descripcion, cantidad, estado, autor_id)
    values (-3200002, v_obra, 'C3 CABLE THHN 12', '1', 'falta', v_dueno);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_puentes_rehacer('recibos', '-3200001', 'c3: la regla estaba mal');
    execute 'reset role';
    select format('rehacer=%s material=%s/%s', coalesce(v_r->>'accion', '-'), m.estado, coalesce(m.recibo_id::text, '-'))
      into v_obt
      from materiales m
     where m.id = -3200002;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (47, 'materiales: la escritura del puente no marca comprado un material nuevo', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 48. Edgar aprueba y retira horas desde el SQL EDITOR (hasta que exista
--     conta.js es su único camino): un reporte normal y otro con el permiso
--     de corrección sin usar se aprueban los dos, sin «pídele permiso a
--     Edgar», y el permiso del trabajador se queda (aprobar no es corregir).
--     Retirar la aprobación también entra.
do $$
declare
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_dia    date;
  v_otros  bigint;
  v_antes  bigint;
  v_ap     jsonb;
  v_des    jsonb;
  v_perm   text;
  v_obt    text;
  v_esp    text;
begin
  if v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (48, 'horas: Edgar aprueba y retira desde el SQL Editor, y el permiso de corrección se queda', '-',
                                 'omitida: falta alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  v_dia := v_desde + 26;
  select count(*) filter (where h.aprobado_el is null), count(*) filter (where h.aprobado_el is not null)
    into v_otros, v_antes
    from horas h where h.usuario_id = v_equipo and h.fecha = v_dia;
  v_esp := format('aprobar=%s permiso=-/aprobada retirar=%s permiso_despues=-/aprobada', v_otros + 2, v_otros + v_antes + 2);
  begin
    insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, notas, correccion_estado, llave_cliente)
    values (-3200010, v_dia, v_equipo, v_obra, 'rough', 8, 'c3-pruebas', null, 'c3-horas-10'),
           (-3200011, v_dia, v_equipo, v_obra, 'rough', 2, 'c3-pruebas', 'aprobada', 'c3-horas-11');
    -- El editor: sin sesión de la API (auth.uid() nulo).
    perform set_config('request.jwt.claims', '', true);
    v_ap := fn_horas_aprobar(v_equipo, v_dia, v_dia);
    select string_agg(coalesce(h.correccion_estado, '-'), '/' order by h.id desc) into v_perm
      from horas h where h.id in (-3200010, -3200011);
    v_des := fn_horas_desaprobar(v_equipo, v_dia, v_dia, 'c3: retiro de prueba');
    select format('aprobar=%s permiso=%s retirar=%s permiso_despues=%s', v_ap->>'reportes', v_perm, v_des->>'reportes',
                  string_agg(coalesce(h.correccion_estado, '-'), '/' order by h.id desc))
      into v_obt
      from horas h where h.id in (-3200010, -3200011);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (48, 'horas: Edgar aprueba y retira desde el SQL Editor, y el permiso de corrección se queda', v_esp,
                               v_obt, v_obt = v_esp);
end $$;

-- 49. Una factura ANULADA con su nota de crédito no se deja marcar cobrada:
--     la app todavía no conoce el estado y la enseña «por cobrar», y ✓
--     cobrada le pondría cobrado = monto (MX003). facturas_cobro no dice
--     «cuadra»: dice anulada, con su nota.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cob   text;
  v_obt   text;
  v_esp   text := 'marcar=MX003 pagada=f cobrado=0.00 aviso=anulada/NC';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (49, 'factura anulada: no se marca cobrada, y facturas_cobro no dice cuadra', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200020, v_obra, 'C3-2020', v_desde + 2, 700.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_factura_anular(-3200020, 'c3: salió duplicada', v_desde + 3);
    begin
      update facturas set pagada = true where id = -3200020;
      v_cob := 'entró';
    exception when others then
      v_cob := sqlstate;
    end;
    execute 'reset role';
    select format('marcar=%s pagada=%s cobrado=%s aviso=%s', v_cob, f.pagada, f.cobrado,
                  case when fc.aviso like 'anulada con la nota de crédito NC-%' then 'anulada/NC' else coalesce(fc.aviso, '-') end)
      into v_obt
      from facturas f left join facturas_cobro fc on fc.id = f.id
     where f.id = -3200020;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (49, 'factura anulada: no se marca cobrada, y facturas_cobro no dice cuadra', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 50. Un ticket de septiembre que la APERTURA nombra (su deuda al 30-sep,
--     partida recibos/<id>): borrarlo da MX003 con lo que de verdad hay que
--     hacer (un ajuste a la apertura), no «ponle el total en 0»; y si se le
--     pone en 0, espera en la bandeja (en_apertura), porque la apertura
--     sigue debiendo.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_corte date := fn_puente_corte();
  v_f     jsonb;
  v_ap    text;
  v_del   text;
  v_obt   text;
  v_esp   text := 'borrar=MX003/apertura en_cero=pendiente/en_apertura';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (50, 'un recibo en la apertura: el MX003 dice la apertura, y en 0 espera en la bandeja', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200030, 'total', '310.00', 'fecha', (v_corte - 3)::text,
                                                 'creado', (v_corte - 3)::text || ' 15:00-04', 'metodo_pago', 'c3 pruebas cuenta'));
    v_ap := pg_temp.c3_apertura('recibos', '-3200030', fn_puente_cuenta_de('cxp'), 310.00, 'proveedor', v_f->>'proveedor');
    if v_ap is null then
      v_obt := 'omitida: no hay período de apertura';
      raise exception using errcode = 'MXT00';
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      delete from recibos where id = -3200030;
      v_del := 'borró';
    exception when others then
      v_del := sqlstate || case when sqlerrm like '%apertura%' and sqlerrm not like '%total en 0 con%' then '/apertura' else '/otro' end;
    end;
    update recibos set total = 0 where id = -3200030;
    execute 'reset role';
    select format('borrar=%s en_cero=%s', v_del,
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3200030'), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (50, 'un recibo en la apertura: el MX003 dice la apertura, y en 0 espera en la bandeja', v_esp, v_obt,
                               case when v_obt like 'omitida%' then null else v_obt = v_esp end);
end $$;

-- 51. REHACER es reverso + asiento nuevo, o nada: una factura anulada con su
--     nota de crédito no se rehace (MX008: la nota ya la compensa; antes el
--     ingreso salía dos veces), y una cuya obra se quedó sin regla de
--     ingreso tampoco (MX008; antes salía del libro con su cobro dentro).
--     Ninguna deja un reverso suelto.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_a     text;
  v_b     text;
  v_obt   text;
  v_esp   text := 'anulada=MX008 sin_regla=MX008 reversos=0 saldo_2041=400.00';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (51, 'rehacer: nunca un reverso suelto (factura anulada, obra sin regla)', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200040, v_obra, 'C3-2040', v_desde + 2, 900.00, 0),
           (-3200041, v_obra, 'C3-2041', v_desde + 2, 400.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_factura_anular(-3200040, 'c3: anulada', v_desde + 3);
    begin
      perform fn_puentes_rehacer('facturas', '-3200040', 'c3: la regla estaba mal');
      v_a := 'rehízo';
    exception when others then
      v_a := sqlstate;
    end;
    execute 'reset role';
    -- La regla del tipo de la obra vuelve a borrador (solo aquí adentro).
    update mapeo_tipo_proyecto set confirmado_el = null, confirmado_por = null, confirmado_rol = null
     where tipo = fn_puente_normalizar(v_f->>'tipo');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_puentes_rehacer('facturas', '-3200041', 'c3: la obra cambió');
      v_b := 'rehízo';
    exception when others then
      v_b := sqlstate;
    end;
    execute 'reset role';
    select format('anulada=%s sin_regla=%s reversos=%s saldo_2041=%s', v_a, v_b,
                  (select count(*) from asientos a
                    where a.origen_tabla = 'facturas' and a.origen_id in ('-3200040', '-3200041') and a.camino = 'reverso'),
                  pg_temp.c3_saldo(fn_puente_cuenta_de('cxc'), 'facturas', '-3200041'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (51, 'rehacer: nunca un reverso suelto (factura anulada, obra sin regla)', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 52. Anular una factura que ESTUVO en el libro y hoy no tiene asiento vivo
--     (se reversó a mano y el puente todavía no la repuso): con un cobro
--     aplicado, MX008 (primero el cobro); sin cobros, MX008 también (primero
--     se repone su asiento). Nunca «anulada sin nota de crédito».
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_a     text;
  v_b     text;
  v_obt   text;
  v_esp   text := 'con_cobro=MX008 sin_cobro=MX008 estados=emitida/emitida notas=0';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (52, 'anular una factura reversada: ni con cobros ni sin su nota de crédito', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200050, v_obra, 'C3-2050', v_desde + 2, 1000.00, 0),
           (-3200051, v_obra, 'C3-2051', v_desde + 2, 600.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '300.00',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200050, 'monto', '300.00'))));
    perform fn_reversar((select f.contabilizado_en from facturas f where f.id = -3200050), 'c3: lo rehago');
    perform fn_reversar((select f.contabilizado_en from facturas f where f.id = -3200051), 'c3: lo rehago');
    begin
      perform fn_factura_anular(-3200050, 'c3: la cambio por otra', v_desde + 6);
      v_a := 'anuló';
    exception when others then
      v_a := sqlstate;
    end;
    begin
      perform fn_factura_anular(-3200051, 'c3: la cambio por otra', v_desde + 6);
      v_b := 'anuló';
    exception when others then
      v_b := sqlstate;
    end;
    execute 'reset role';
    select format('con_cobro=%s sin_cobro=%s estados=%s notas=%s', v_a, v_b,
                  (select string_agg(f.estado, '/' order by f.id desc) from facturas f where f.id in (-3200050, -3200051)),
                  (select count(*) from notas_credito n where n.anula_a in (-3200050, -3200051)))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (52, 'anular una factura reversada: ni con cobros ni sin su nota de crédito', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 53. Fechado ANTES del corte pero subido DESPUÉS (un año mal leído, un
--     ticket de septiembre que llegó tarde): un recibo y un trabajo externo
--     así no se callan, esperan en la bandeja (fecha_antes_del_corte). Edgar
--     confirma uno (fn_puentes_antes_del_corte): pasa a no_aplica. Y el
--     ticket de septiembre subido en septiembre sigue como siempre
--     (no_aplica, sin bandeja).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_corte date := fn_puente_corte();
  v_obt   text;
  v_esp   text := '-3200060=pendiente/fecha_antes_del_corte -3200061=no_aplica/antes_del_corte '
                  '-3200062=no_aplica/antes_del_corte -3200063=pendiente/fecha_antes_del_corte bandeja=-3200060,-3200063';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (53, 'fechado antes del corte y subido después: a la bandeja, y Edgar lo confirma', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200060, 'total', '845.20', 'fecha', (v_corte - 354)::text,
                                                 'creado', (v_desde + 11)::text || ' 10:00-04'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200061, 'total', '1210.00', 'fecha', (v_corte - 2)::text,
                                                 'creado', (v_desde + 19)::text || ' 10:00-04'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200062, 'total', '99.00', 'fecha', (v_corte - 2)::text,
                                                 'creado', (v_corte - 2)::text || ' 15:00-04'));
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo, creado) overriding system value
    values (-3200063, v_obra, 'c3-pruebas: zanja de septiembre', v_corte - 5, 'ajuste', null, 500.00,
            ((v_desde + 14)::text || ' 10:00-04')::timestamptz);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_puentes_antes_del_corte('recibos', -3200061, 'c3: ticket de septiembre, ya está en QuickBooks');
    execute 'reset role';
    select string_agg(x.documento_id || '=' || x.e, ' ' order by x.documento_id::bigint desc) || ' bandeja='
           || coalesce((select string_agg(b.documento_id, ',' order by b.documento_id::bigint desc) from puentes_bandeja b
                         where b.documento_id in ('-3200060', '-3200061', '-3200062', '-3200063')), '-')
      into v_obt
      from (select d.documento_id, d.estado || '/' || d.codigo as e from puente_documentos d
             where (d.tabla, d.documento_id) in (('recibos', '-3200060'), ('recibos', '-3200061'), ('recibos', '-3200062'),
                                                 ('trabajos_externos', '-3200063'))) x;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (53, 'fechado antes del corte y subido después: a la bandeja, y Edgar lo confirma', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 54. Una tarjeta y un proveedor que se marcan INACTIVOS frenan lo nuevo, no
--     lo que ya se les cargó: a un recibo contabilizado de cada uno se le
--     pone la foto (📷) y su deuda sigue en su cuenta (reverso + sustituto,
--     la misma cuenta); un recibo nuevo a la tarjeta inactiva espera en la
--     bandeja diciendo «inactiva» (no «no está dada de alta»).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_obt   text;
  v_esp   text := 'tarjeta=3/1:-245.37 cxp=3/1:-1288.10 nuevo=pendiente/tarjeta/inactiva';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (54, 'inactivos frenan lo nuevo, no la deuda que ya estaba', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200070, 'total', '245.37'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200071, 'total', '1288.10', 'metodo_pago', 'c3 pruebas cuenta'));
    update tarjetas set activa = false where ultimos4 = '9998';
    update proveedores set activo = false where id = (v_f->>'proveedor')::uuid;
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set ruta = 'recibos/c3-pruebas/70-bis.jpg' where id = -3200070;
    update recibos set ruta = 'recibos/c3-pruebas/71-bis.jpg' where id = -3200071;
    execute 'reset role';
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200072, 'total', '20.00'));
    select format('tarjeta=%s:%s cxp=%s:%s nuevo=%s', pg_temp.c3_cuantos('recibos', '-3200070'),
                  coalesce((select l.monto::text from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('recibos', '-3200070') and l.cuenta = '2100-9998'), '-'),
                  pg_temp.c3_cuantos('recibos', '-3200071'),
                  pg_temp.c3_saldo(fn_puente_cuenta_de('cxp'), 'recibos', '-3200071'),
                  coalesce((select d.estado || '/' || d.codigo || '/' || case when d.motivo like '%inactiva%' then 'inactiva' else 'otro' end
                              from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3200072'), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (54, 'inactivos frenan lo nuevo, no la deuda que ya estaba', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 55. Un ticket que ya está en la APERTURA (su deuda al 30-sep, partida
--     recibos/<id>) no vuelve a entrar por su puente cuando su fecha se
--     corrige al corte o después: espera en la bandeja (en_apertura) y la
--     partida debe lo que decía la apertura, no el doble. Y al revés (el
--     puente primero, la apertura después), el control partidas lo marca.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_corte date := fn_puente_corte();
  v_f     jsonb;
  v_ap    text;
  v_obt   text;
  v_esp   text := 'estado=pendiente/en_apertura partida=-500.00 propios=0/0 doble=false';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (55, 'lo que está en la apertura no entra dos veces', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    -- Subido el 2-oct con la fecha leída del 29-sep: es de septiembre y la
    -- apertura lo nombra (no_aplica). (Uno SUBIDO antes del corte es de
    -- antes del corte diga lo que diga la fecha: prueba 84.)
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200080, 'total', '500.00', 'fecha', (v_corte - 2)::text,
                                                 'creado', (v_corte + 1)::text || ' 17:00-04', 'metodo_pago', 'c3 pruebas cuenta'));
    v_ap := pg_temp.c3_apertura('recibos', '-3200080', fn_puente_cuenta_de('cxp'), 500.00, 'proveedor', v_f->>'proveedor');
    if v_ap is null then
      v_obt := 'omitida: no hay período de apertura';
      raise exception using errcode = 'MXT00';
    end if;
    -- La fecha estaba mal leída: la buena es la del corte.
    update recibos set fecha = v_desde where id = -3200080;
    -- Al revés: el puente lo contabiliza primero y la apertura lo nombra después.
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200081, 'total', '75.00', 'metodo_pago', 'c3 pruebas cuenta'));
    perform pg_temp.c3_apertura('recibos', '-3200081', fn_puente_cuenta_de('cxp'), 75.00, 'proveedor', v_f->>'proveedor');
    select format('estado=%s partida=%s propios=%s doble=%s',
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3200080'), '-'),
                  pg_temp.c3_saldo(fn_puente_cuenta_de('cxp'), 'recibos', '-3200080'),
                  pg_temp.c3_cuantos('recibos', '-3200080'),
                  coalesce((select v.ok::text from fn_puentes_verificar() v where v.control = 'partidas'), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (55, 'lo que está en la apertura no entra dos veces', v_esp, v_obt,
                               case when v_obt like 'omitida%' then null else v_obt = v_esp end);
end $$;

-- 56. La RETENCIÓN de una factura a un GC no entra entera a 1110: sin
--     retención dicha, la factura espera en la bandeja (retencion); dicha,
--     postea 1110 y 1120, y su retención se cobra desde 1120.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_antes text;
  v_obt   text;
  v_esp   text;
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (56, 'retención de un GC: espera a que se diga, y va a 1120', '-',
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    v_esp := format('antes=pendiente/retencion lineas=%s:9000.00:%s:-:-:facturas/-3200090 | %s:1000.00:%s:-:-:facturas/-3200090 | '
                    '%s:-10000.00:%s:-:-:- cobrada=0.00/0.00',
                    fn_puente_cuenta_de('cxc'), v_obra, fn_puente_cuenta_de('retencion_cxc'), v_obra, v_f->>'ingreso', v_obra);
    insert into facturas (id, proyecto_id, num, fecha, monto, a_contratista) overriding system value
    values (-3200090, v_obra, 'C3-2090', v_desde + 2, 10000.00, true);
    select d.estado || '/' || d.codigo into v_antes from puente_documentos d where d.tabla = 'facturas' and d.documento_id = '-3200090';
    update facturas set retencion = 1000.00 where id = -3200090;
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '9000.00',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200090, 'monto', '9000.00'))));
    perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 6)::text, 'monto', '1000.00',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200090, 'monto', '1000.00', 'es_retencion', true))));
    execute 'reset role';
    select format('antes=%s lineas=%s cobrada=%s/%s', coalesce(v_antes, '-'),
                  pg_temp.c3_lineas(pg_temp.c3_vivo('facturas', '-3200090')),
                  pg_temp.c3_saldo(fn_puente_cuenta_de('cxc'), 'facturas', '-3200090'),
                  pg_temp.c3_saldo(fn_puente_cuenta_de('retencion_cxc'), 'facturas', '-3200090'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (56, 'retención de un GC: espera a que se diga, y va a 1120', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 57. El DEVENGO sigue a las horas aprobadas: si unas horas se pasan a otra
--     obra y se vuelven a aprobar, el control devengo lo marca y
--     fn_horas_devengar lo rehace (antes decía «sin_cambios» y el costo se
--     quedaba en la obra vieja).
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_obra2  text;
  v_costo  numeric;
  v_ctl    text;
  v_r      jsonb;
  v_obt    text;
  v_esp    text;
begin
  select p.id into v_obra2 from proyectos p where p.id <> v_obra and nullif(btrim(p.tipo), '') is not null order by p.id limit 1;
  if v_dueno is null or v_equipo is null or v_obra is null or v_obra2 is null or v_desde is null or v_mes is null then
    insert into _pruebas values (57, 'devengo: si las horas cambian de obra, el control lo marca y se rehace', '-',
                                 'omitida: falta dueño, alguien del equipo, dos obras o mes abierto', null);
    return;
  end if;
  begin
    insert into costos_equipo (usuario_id, costo_hora) values (v_equipo, 30.00) on conflict (usuario_id) do nothing;
    select ce.costo_hora into v_costo from costos_equipo ce where ce.usuario_id = v_equipo;
    v_esp := format('antes=false accion=sustituido obra2=%s obra1=- despues=true', round(8 * v_costo, 2));
    insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, notas, co, llave_cliente)
    values (-3200100, v_desde + 3, v_equipo, v_obra, 'rough', 8, 'c3-pruebas', 'C3-DEV', 'c3-horas-100');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 3, v_desde + 3);
    perform fn_horas_devengar(v_mes);
    update horas set proyecto_id = v_obra2 where id = -3200100;
    perform fn_horas_aprobar(v_equipo, v_desde + 3, v_desde + 3);
    execute 'reset role';
    select v.ok::text into v_ctl from fn_puentes_verificar() v where v.control = 'devengo';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_horas_devengar(v_mes);
    execute 'reset role';
    select format('antes=%s accion=%s obra2=%s obra1=%s despues=%s', coalesce(v_ctl, '-'), v_r->>'accion',
                  coalesce((select l.monto::text from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('horas_devengo', v_mes) and l.co = 'C3-DEV' and l.proyecto_id = v_obra2), '-'),
                  coalesce((select l.monto::text from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('horas_devengo', v_mes) and l.co = 'C3-DEV' and l.proyecto_id = v_obra), '-'),
                  coalesce((select v.ok::text from fn_puentes_verificar() v where v.control = 'devengo'), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (57, 'devengo: si las horas cambian de obra, el control lo marca y se rehace', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 58. Un trabajo externo «escrito libre» (sin ayudante de la nómina: lo
--     normal en un subcontrato) entra al costo de la obra, con un AVISO en
--     la bandeja (sin proveedor: su deuda no sale por proveedor ni en el
--     1099). Con su proveedor_id, la deuda queda a nombre del proveedor y el
--     aviso se va.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_f     jsonb;
  v_antes text;
  v_obt   text;
  v_esp   text := 'antes=aviso/sin_proveedor despues=fuera tercero=proveedor/suyo costo=2400.00';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (58, 'trabajo externo sin proveedor: aviso en la bandeja; con proveedor_id, a su nombre', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, horas, costo) overriding system value
    values (-3200110, v_obra, 'c3-pruebas: zanja a precio cerrado', v_desde + 4, 'ajuste', null, 2400.00);
    select b.estado || '/' || b.codigo into v_antes from puentes_bandeja b
     where b.tabla = 'trabajos_externos' and b.documento_id = '-3200110';
    update trabajos_externos set proveedor_id = (v_f->>'proveedor')::uuid where id = -3200110;
    select format('antes=%s despues=%s tercero=%s costo=%s', coalesce(v_antes, '-'),
                  coalesce((select b.estado || '/' || b.codigo from puentes_bandeja b
                             where b.tabla = 'trabajos_externos' and b.documento_id = '-3200110'), 'fuera'),
                  coalesce((select l.tercero_tipo || '/' || case when l.tercero_id = v_f->>'proveedor' then 'suyo' else 'otro' end
                              from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('trabajos_externos', '-3200110')
                               and l.cuenta = fn_puente_cuenta_de('cxp')), '-'),
                  coalesce((select l.monto::text from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('trabajos_externos', '-3200110')
                               and l.cuenta = fn_puente_cuenta_de('subcontratos')), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (58, 'trabajo externo sin proveedor: aviso en la bandeja; con proveedor_id, a su nombre', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 59. Un cobro mal aplicado se ANULA y el bueno lleva el MISMO movimiento
--     del banco (el anulado lo conserva como rastro). Dos cobros VIGENTES con
--     el mismo movimiento, no (MX008, en español).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_r     jsonb;
  v_2     text;
  v_3     text;
  v_obt   text;
  v_esp   text := 'dos_vigentes=MX008 corregido=entró cobros=anulado/vigente';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (59, 'un cobro anulado deja su movimiento del banco al bueno', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200120, v_obra, 'C3-2120', v_desde + 2, 1000.00, 0),
           (-3200121, v_obra, 'C3-2121', v_desde + 2, 1000.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '300.00', 'movimiento_id', 'c3-pruebas-mov-59',
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200120, 'monto', '300.00'))));
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '300.00', 'movimiento_id', 'c3-pruebas-mov-59',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200121, 'monto', '300.00'))));
      v_2 := 'entró';
    exception when others then
      v_2 := sqlstate;
    end;
    perform fn_cobro_anular((v_r->>'cobro')::uuid, 'c3: aplicado a la factura equivocada');
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '300.00', 'movimiento_id', 'c3-pruebas-mov-59',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200121, 'monto', '300.00'))));
      v_3 := 'entró';
    exception when others then
      v_3 := sqlstate;
    end;
    execute 'reset role';
    select format('dos_vigentes=%s corregido=%s cobros=%s', v_2, v_3, string_agg(c.estado, '/' order by c.estado))
      into v_obt
      from cobros c where c.movimiento_id = 'c3-pruebas-mov-59';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (59, 'un cobro anulado deja su movimiento del banco al bueno', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 60. El devengo estándar no mete las horas de EDGAR: es el oficial de la
--     S-corp y cobra su salario por nómina (su parte de obra es 5001, del
--     journal). Sus horas aprobadas quedan fuera (oficial) y ninguna línea
--     del devengo es suya.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes   text := nullif(current_setting('mx3.mes', true), '');
  v_ofi   int;
  v_obt   text;
  v_esp   text := 'oficial=si linea_de_edgar=0';
begin
  if v_dueno is null or v_obra is null or v_desde is null or v_mes is null then
    insert into _pruebas values (60, 'devengo: las horas del dueño (oficial) no entran', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    insert into costos_equipo (usuario_id, costo_hora) values (v_dueno, 45.00) on conflict (usuario_id) do nothing;
    insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, notas, co, llave_cliente)
    values (-3200130, v_desde + 3, v_dueno, v_obra, 'rough', 6, 'c3-pruebas', 'C3-OFI', 'c3-horas-130');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_dueno, v_desde + 3, v_desde + 3);
    begin
      perform fn_horas_devengar(v_mes);
    exception when sqlstate 'MX008' then
      null;  -- sin otras horas en el mes: no hay devengo, y ninguna línea de Edgar
    end;
    execute 'reset role';
    -- El plan del devengo es del bloque B: en rojo no existe (y la prueba
    -- sigue y dice qué no pasó, sin fallar por una función que falta).
    if to_regprocedure('public.fn_puente_devengo_plan(text)') is not null then
      execute 'select coalesce((public.fn_puente_devengo_plan($1)->''fuera''->>''oficial'')::int, 0)' into v_ofi using v_mes;
    end if;
    select format('oficial=%s linea_de_edgar=%s',
                  case when coalesce(v_ofi, 0) >= 1 then 'si' else 'no' end,
                  (select count(*) from asiento_lineas l
                    where l.asiento_id = pg_temp.c3_vivo('horas_devengo', v_mes) and l.co = 'C3-OFI'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (60, 'devengo: las horas del dueño (oficial) no entran', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 61. Una factura que queda en NEGATIVO en el libro (su ingreso se reversó
--     y tenía un cobro aplicado) no dice «cuadra»: facturas_cobro lo avisa y
--     el control partidas de fn_puentes_verificar se pone en rojo.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_obt   text;
  v_esp   text := 'saldo=-400.00 aviso=en_negativo partidas=false';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (61, 'una factura en negativo no cuadra: aviso y control partidas', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200140, v_obra, 'C3-2140', v_desde + 2, 1000.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '400.00',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200140, 'monto', '400.00'))));
    perform fn_reversar((select f.contabilizado_en from facturas f where f.id = -3200140), 'c3: lo rehago');
    execute 'reset role';
    select format('saldo=%s aviso=%s partidas=%s', fc.saldo_libro,
                  case when fc.aviso like 'en negativo en el libro%' then 'en_negativo' else fc.aviso end,
                  coalesce((select v.ok::text from fn_puentes_verificar() v where v.control = 'partidas'), '-'))
      into v_obt
      from facturas_cobro fc where fc.id = -3200140;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (61, 'una factura en negativo no cuadra: aviso y control partidas', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 62. Lo cobrado ANTES de la fecha de la factura no se le aplica (al cierre
--     de ese mes la cuenta por cobrar enseñaría una factura que aún no
--     existía): MX002, se deja de anticipo. Un anticipo tampoco se aplica
--     antes de la factura (MX002); desde su fecha, sí.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_ant   jsonb;
  v_a     text;
  v_b     text;
  v_c     text;
  v_obt   text;
  v_esp   text;
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (62, 'un cobro no se aplica a una factura posterior; el anticipo, desde su fecha', '-',
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  v_esp := format('cobro=MX002 anticipo_antes=MX002 anticipo_despues=%s', v_desde + 20);
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200150, v_obra, 'C3-2150', v_desde + 20, 800.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 10)::text, 'monto', '800.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200150, 'monto', '800.00'))));
      v_a := 'entró';
    exception when others then
      v_a := sqlstate;
    end;
    v_ant := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 10)::text, 'monto', '800.00',
               'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '800.00'))));
    begin
      perform fn_anticipo_aplicar((v_ant->>'cobro')::uuid, -3200150, '800.00', v_desde + 15);
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    begin
      v_c := fn_anticipo_aplicar((v_ant->>'cobro')::uuid, -3200150, '800.00', v_desde + 20)->>'fecha_contable';
    exception when others then
      v_c := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('cobro=%s anticipo_antes=%s anticipo_despues=%s', v_a, v_b, coalesce(v_c, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (62, 'un cobro no se aplica a una factura posterior; el anticipo, desde su fecha', v_esp, v_obt,
                               v_obt = v_esp);
end $$;

-- 63. Cada cuenta en su CLASE: un cobro no entra a la depreciación acumulada
--     ni a la cuenta del accionista (solo a un banco, 10xx); una forma de
--     pago «banco» no sale de la bodega; la cuenta por cobrar de los puentes
--     no puede ser un costo, ni la de por pagar un banco (MX004).
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_activo text;
  v_a      text;
  v_b      text;
  v_c      text;
  v_d      text;
  v_obt    text;
  v_esp    text := 'cobro_no_banco=MX004 banco_no_banco=MX004 cxc_costo=MX004 cxp_banco=MX004';
begin
  -- Una cuenta de activo sin obra que NO es un banco (la depreciación
  -- acumulada, la bodega, la del accionista…).
  select c.codigo into v_activo from cuentas c
   where c.tipo = 'activo' and left(c.codigo, 2) <> '10' and c.regla_obra = 'prohibida' and c.activa and c.imputable
   order by (c.codigo = '1590') desc, c.codigo limit 1;
  if v_dueno is null or v_obra is null or v_desde is null or v_activo is null then
    insert into _pruebas values (63, 'cada cuenta de los puentes y del cobro es de su clase', v_esp,
                                 'omitida: falta dueño, obra, mes abierto o una cuenta de activo que no es banco', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200160, v_obra, 'C3-2160', v_desde + 2, 500.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '100.00', 'cuenta', v_activo,
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200160, 'monto', '100.00'))));
      v_a := 'entró';
    exception when others then
      v_a := sqlstate;
    end;
    begin
      perform fn_mapeo_metodo_pago('c3 pruebas banco raro', 'banco', v_activo);
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    begin
      perform fn_puentes_cuenta('cxc', current_setting('mx3.material'));
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
    end;
    begin
      perform fn_puentes_cuenta('cxp', current_setting('mx3.banco'));
      v_d := 'entró';
    exception when others then
      v_d := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('cobro_no_banco=%s banco_no_banco=%s cxc_costo=%s cxp_banco=%s', v_a, v_b, v_c, v_d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (63, 'cada cuenta de los puentes y del cobro es de su clase', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 64. El BURDEN (5010-5019) también se vigila, como lo dice c1: un 5010 por
--     obra pagado desde el banco, o un 5015 (impuestos patronales) pagado
--     directo, se marcan en el control mano_de_obra; la amortización de la
--     prima de WC (5015 contra 1410) y el reparto a la obra (5010 contra
--     5015) no.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_n     text[] := '{}';
  v_mal   jsonb;
  v_obt   text;
  v_esp   text := 'obra_desde_banco=marcado real_desde_banco=marcado amortizacion_wc=no reparto=no';
begin
  if v_dueno is null or v_obra is null or v_desde is null
     or (select count(*) from cuentas c where c.codigo in ('5010', '5015', '1410') and c.activa and c.imputable) < 3 then
    insert into _pruebas values (64, 'el control de mano de obra vigila también el burden (5010-5019)', v_esp,
                                 'omitida: falta dueño, obra, mes abierto o las cuentas 5010, 5015 y 1410', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_n := v_n || (fn_postear(jsonb_build_object('fecha', (v_desde + 5)::text, 'descripcion', 'c3-pruebas: burden a ojo',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5010', 'monto', '900.00', 'proyecto_id', v_obra),
                                                 jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '-900.00'))))->>'numero');
    v_n := v_n || (fn_postear(jsonb_build_object('fecha', (v_desde + 5)::text, 'descripcion', 'c3-pruebas: impuestos patronales',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '350.00'),
                                                 jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '-350.00'))))->>'numero');
    v_n := v_n || (fn_postear(jsonb_build_object('fecha', (v_desde + 5)::text, 'descripcion', 'c3-pruebas: amortización de WC',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5015', 'monto', '120.00'),
                                                 jsonb_build_object('cuenta', '1410', 'monto', '-120.00'))))->>'numero');
    v_n := v_n || (fn_postear(jsonb_build_object('fecha', (v_desde + 5)::text, 'descripcion', 'c3-pruebas: reparto del burden',
                     'lineas', jsonb_build_array(jsonb_build_object('cuenta', '5010', 'monto', '120.00', 'proyecto_id', v_obra),
                                                 jsonb_build_object('cuenta', '5015', 'monto', '-120.00'))))->>'numero');
    execute 'reset role';
    select v.detalle->'asientos' into v_mal from fn_puentes_verificar() v where v.control = 'mano_de_obra';
    v_obt := format('obra_desde_banco=%s real_desde_banco=%s amortizacion_wc=%s reparto=%s',
                    case when coalesce(v_mal ? v_n[1], false) then 'marcado' else 'no' end,
                    case when coalesce(v_mal ? v_n[2], false) then 'marcado' else 'no' end,
                    case when coalesce(v_mal ? v_n[3], false) then 'marcado' else 'no' end,
                    case when coalesce(v_mal ? v_n[4], false) then 'marcado' else 'no' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (64, 'el control de mano de obra vigila también el burden (5010-5019)', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 65. El MISMO cobro mandado dos veces (un doble toque, un reintento tras un
--     corte de red) entra UNA vez: con su llave_cliente, la segunda devuelve
--     el que ya estaba; con la misma llave y otros datos, MX008. Igual un
--     anticipo (sin factura que lo frene por saldo).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_1     jsonb;
  v_2     jsonb;
  v_3     text;
  v_a1    jsonb;
  v_a2    jsonb;
  v_obt   text;
  v_esp   text := 'segunda=true/mismo otra=MX008 anticipo=true/mismo cobros=2';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (65, 'el mismo cobro dos veces entra una (llave_cliente)', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200170, v_obra, 'C3-2170', v_desde + 2, 2000.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_1 := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '1000.00', 'medio', 'cheque',
             'referencia', '5521', 'llave_cliente', 'c3-pruebas-llave-65a',
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200170, 'monto', '1000.00'))));
    v_2 := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '1000.00', 'medio', 'cheque',
             'referencia', '5521', 'llave_cliente', 'c3-pruebas-llave-65a',
             'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200170, 'monto', '1000.00'))));
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '900.00', 'llave_cliente', 'c3-pruebas-llave-65a',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3200170, 'monto', '900.00'))));
      v_3 := 'entró';
    exception when others then
      v_3 := sqlstate;
    end;
    v_a1 := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 6)::text, 'monto', '2500.00', 'llave_cliente', 'c3-pruebas-llave-65b',
              'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '2500.00'))));
    v_a2 := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 6)::text, 'monto', '2500.00', 'llave_cliente', 'c3-pruebas-llave-65b',
              'aplicaciones', jsonb_build_array(jsonb_build_object('proyecto_id', v_obra, 'monto', '2500.00'))));
    execute 'reset role';
    select format('segunda=%s/%s otra=%s anticipo=%s/%s cobros=%s', coalesce(v_2->>'ya_estaba', '-'),
                  case when v_2->>'cobro' = v_1->>'cobro' then 'mismo' else 'otro' end, v_3,
                  coalesce(v_a2->>'ya_estaba', '-'), case when v_a2->>'cobro' = v_a1->>'cobro' then 'mismo' else 'otro' end,
                  (select count(*) from cobros c where c.llave_cliente in ('c3-pruebas-llave-65a', 'c3-pruebas-llave-65b')))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (65, 'el mismo cobro dos veces entra una (llave_cliente)', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 66. Los últimos 4 de la tarjeta como los imprime el ticket («*9998»,
--     «XXXX9998») casan con la tarjeta; unos que no traen 4 dígitos («*98»)
--     esperan diciendo qué corregir, sin proponer un alta que la tabla
--     rechaza; y fn_tarjeta_alta acepta «XXXX9997».
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_alta  text;
  v_obt   text;
  v_esp   text := '-3200180=contabilizado -3200181=contabilizado -3200182=pendiente/tarjeta/corrige alta=9997';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (66, 'últimos 4 con adornos: casan con la tarjeta', v_esp, 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200180, 'total', '23.00', 'ultimos4', '*9998'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200181, 'total', '24.00', 'ultimos4', 'XXXX9998'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200182, 'total', '25.00', 'ultimos4', '*98'));
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2100-9997', 'c3-pruebas: otra tarjeta', 'c3 test card 2', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
    on conflict (codigo) do nothing;
    v_alta := fn_tarjeta_alta('XXXX9997', '2100-9997', 'c3-pruebas: otra')->>'ultimos4';
    select string_agg(d.documento_id || '=' || d.estado
                      || case when d.estado = 'pendiente'
                              then '/' || d.codigo || '/' || case when d.motivo like '%fn_tarjeta_alta%' then 'propone_alta' else 'corrige' end
                              else '' end, ' ' order by d.documento_id::bigint desc) || ' alta=' || coalesce(v_alta, '-')
      into v_obt
      from puente_documentos d
     where d.tabla = 'recibos' and d.documento_id in ('-3200180', '-3200181', '-3200182');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (66, 'últimos 4 con adornos: casan con la tarjeta', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 67. Si Edgar retira todas las aprobaciones de un mes con devengo, volver a
--     devengar lo DESHACE (reverso en su fecha, que anula su reverso del día
--     1): el mes queda en cero, no con un devengo sin horas detrás.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_r      jsonb;
  v_obt    text;
  v_esp    text := 'accion=reversado mes=0.00/0.00 estado=no_aplica/sin_horas';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null or v_mes is null then
    insert into _pruebas values (67, 'devengo: sin horas aprobadas, se deshace', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    insert into costos_equipo (usuario_id, costo_hora) values (v_equipo, 30.00) on conflict (usuario_id) do nothing;
    insert into horas (id, fecha, usuario_id, proyecto_id, fase, horas, notas, llave_cliente)
    values (-3200190, v_desde + 3, v_equipo, v_obra, 'rough', 8, 'c3-pruebas', 'c3-horas-190');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 3, v_desde + 3);
    perform fn_horas_devengar(v_mes);
    -- Se retiran TODAS las aprobaciones del mes (solo aquí adentro).
    update horas set aprobado_por = null, aprobado_el = null
     where fecha between (select p.desde from periodos p where p.periodo = v_mes) and (select p.hasta from periodos p where p.periodo = v_mes)
       and aprobado_el is not null;
    v_r := fn_horas_devengar(v_mes);
    execute 'reset role';
    select format('accion=%s mes=%s/%s estado=%s', v_r->>'accion',
                  coalesce(sum(l.monto) filter (where l.cuenta = fn_puente_cuenta_de('mano_obra')), 0),
                  coalesce(sum(l.monto) filter (where l.cuenta = fn_puente_cuenta_de('sueldos_devengados')), 0),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'horas_devengo' and d.documento_id = v_mes), '-'))
      into v_obt
      from asiento_lineas l join asientos a on a.id = l.asiento_id
     where a.periodo = v_mes and a.origen_tabla = 'horas_devengo';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (67, 'devengo: sin horas aprobadas, se deshace', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 68. Una factura SIN FECHA que se anula (nunca entró al libro) sale de la
--     bandeja: queda no_aplica, no pendiente pidiendo una fecha que ya no
--     importa.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_obt   text;
  v_esp   text := 'antes=pendiente/sin_fecha despues=no_aplica/anulada en_bandeja=0';
  v_antes text;
begin
  if v_dueno is null or v_obra is null then
    insert into _pruebas values (68, 'una factura sin fecha anulada sale de la bandeja', v_esp, 'omitida: falta dueño u obra', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3200200, v_obra, 'C3-2200', null, 900.00, 0);
    select d.estado || '/' || d.codigo into v_antes from puente_documentos d where d.tabla = 'facturas' and d.documento_id = '-3200200';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_factura_anular(-3200200, 'c3: se emitió por error');
    execute 'reset role';
    select format('antes=%s despues=%s en_bandeja=%s', coalesce(v_antes, '-'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'facturas' and d.documento_id = '-3200200'), '-'),
                  (select count(*) from puentes_bandeja b where b.tabla = 'facturas' and b.documento_id = '-3200200'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (68, 'una factura sin fecha anulada sale de la bandeja', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 69. El equipo no escribe por las VISTAS de la app (recibos_equipo corre con
--     los permisos de su dueño y se saltaba la RLS): ni editar un recibo, ni
--     borrarlo, ni meter uno a nombre de otro sin sesión (anon). Y aunque
--     alguien le vuelva a dar escritura a la vista, la guarda del recibo lo
--     para igual (42501) y el control vistas se pone en rojo.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_a      text;
  v_b      text;
  v_c      text;
  v_d      text;
  v_e      text;
  v_f      text;
  v_ctl    text;
  v_obt    text;
  v_esp    text := 'editar=42501 borrar=42501 anon=42501 con_escritura=42501/42501/42501 control=false asientos=1/0';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null or to_regclass('public.recibos_equipo') is null then
    insert into _pruebas values (69, 'el equipo no escribe recibos por recibos_equipo', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra, mes abierto o la vista recibos_equipo', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3200210, 'total', '140.00'));
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update recibos_equipo set estado = 'anulado' where id = -3200210;
      v_a := 'entró';
    exception when others then
      v_a := sqlstate;
    end;
    begin
      delete from recibos_equipo where id = -3200210;
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    begin
      insert into recibos_equipo (id, proyecto_id, ruta, estado, autor_id)
      values (-3200211, v_obra, 'recibos/c3-pruebas/anon.jpg', 'por_leer', v_dueno);
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
    end;
    execute 'reset role';
    -- Alguien le vuelve a dar escritura a la vista (solo aquí adentro).
    grant insert, update, delete on public.recibos_equipo to anon, authenticated;
    select v.ok::text into v_ctl from fn_puentes_verificar() v where v.control = 'vistas';
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update recibos_equipo set estado = 'anulado' where id = -3200210;
      v_d := 'entró';
    exception when others then
      v_d := sqlstate;
    end;
    begin
      delete from recibos_equipo where id = -3200210;
      v_e := 'entró';
    exception when others then
      v_e := sqlstate;
    end;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    begin
      insert into recibos_equipo (id, proyecto_id, ruta, estado, autor_id)
      values (-3200211, v_obra, 'recibos/c3-pruebas/anon.jpg', 'por_leer', v_dueno);
      v_f := 'entró';
    exception when others then
      v_f := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('editar=%s borrar=%s anon=%s con_escritura=%s/%s/%s control=%s asientos=%s', v_a, v_b, v_c, v_d, v_e, v_f,
                    coalesce(v_ctl, '-'), pg_temp.c3_cuantos('recibos', '-3200210'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (69, 'el equipo no escribe recibos por recibos_equipo', v_esp, v_obt, v_obt = v_esp);
end $$;

-- =====================================================================
-- Ronda 4: lo que la verificación encontró (cada prueba habría fallado
-- antes de su arreglo)
-- =====================================================================

-- 70. Un recibo leído SIN forma de pago (el total tecleado con ✎, o una
--     compra anotada a mano): si su proveedor tiene términos (una cuenta
--     abierta con él), va a su cuenta, y la procedencia dice que se derivó
--     de proveedores.terminos; si no, espera con el SQL exacto para
--     escribirla. Y uno por leer no invita a terminar la lectura con ✎: dice
--     que así queda sin forma de pago. Antes la bandeja mandaba al ✎, y
--     después pedía una forma de pago que la app no tiene dónde escribir.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_obt   text;
  v_esp   text;
begin
  v_esp := format('con_terminos=contabilizado:%s:proveedor:proveedores.terminos sin_terminos=pendiente/metodo_pago da_el_sql=t '
                  'por_leer=espera/por_leer avisa=t', fn_puente_cuenta_de('cxp'));
  if v_obra is null or v_desde is null then
    insert into _pruebas values (70, 'sin forma de pago: a la cuenta del proveedor con términos, o espera con el SQL', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300001, 'total', '88.00', 'metodo_pago', null, 'ultimos4', null,
                                                 'proveedor', 'C3 Pruebas Supply Inc'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300002, 'total', '19.99', 'metodo_pago', null, 'ultimos4', null,
                                                 'proveedor', 'c3 pruebas sin cuenta'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300003, 'total', '50.00', 'estado', 'por_leer', 'metodo_pago', null,
                                                 'ultimos4', null));
    select format('con_terminos=%s:%s:%s:%s sin_terminos=%s da_el_sql=%s por_leer=%s avisa=%s',
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300001'), '-'),
                  coalesce((select l.cuenta from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('recibos', '-3300001') and l.monto < 0), '-'),
                  coalesce((select l.tercero_tipo from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('recibos', '-3300001') and l.monto < 0), '-'),
                  coalesce((select a.procedencia->'reglas'->'metodo_pago'->>'derivada_de' from asientos a
                             where a.id = pg_temp.c3_vivo('recibos', '-3300001')), '-'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3300002'), '-'),
                  coalesce((select d.motivo like '%update recibos set metodo_pago = %where id = -3300002;%' from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3300002'), false),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3300003'), '-'),
                  coalesce((select d.motivo like '%queda sin forma de pago%' from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3300003'), false))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (70, 'sin forma de pago: a la cuenta del proveedor con términos, o espera con el SQL', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 71. Un recibo REPETIDO sin obra (gasolina) que ya entró al libro: el 🗑
--     dice que se anula con fn_recibo_anular (lo único que lo saca de «📥
--     Por completar», que solo suelta un anulado o uno con obra). Si antes
--     se le puso el total en 0, el 🗑 ya no dice «no hace falta hacer más»:
--     dice que se anule para quitarlo de las listas. Anulado, sale de la
--     lista.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_b1    text;
  v_m1    text;
  v_tc    text;
  v_b2    text;
  v_m2    text;
  v_obt   text;
  v_esp   text := 'borrar=MX003/anular total_cero=no_aplica/total_cero borrar_otra_vez=MX003/anular/sin_no_hace_falta '
                  'anular=anulado por_completar=f';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (71, 'un repetido sin obra sale de «Por completar» anulándolo, y el 🗑 lo dice', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300010, 'total', '45.00', 'categoria', 'c3 pruebas gasolina',
                                                 'proyecto_id', null));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      delete from recibos where id = -3300010;
      v_b1 := 'entró';
    exception when others then
      v_b1 := sqlstate;
      v_m1 := sqlerrm;
    end;
    -- Lo que decía el mensaje de antes: el total en 0 con ✎.
    update recibos set total = 0, estado = 'leido' where id = -3300010;
    v_tc := (select d.estado || '/' || d.codigo from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300010');
    begin
      delete from recibos where id = -3300010;
      v_b2 := 'entró';
    exception when others then
      v_b2 := sqlstate;
      v_m2 := sqlerrm;
    end;
    perform fn_recibo_anular(-3300010, 'c3: se subió dos veces');
    execute 'reset role';
    select format('borrar=%s total_cero=%s borrar_otra_vez=%s anular=%s por_completar=%s',
                  v_b1 || case when v_m1 like '%fn_recibo_anular(-3300010,%' then '/anular' else '' end,
                  coalesce(v_tc, '-'),
                  v_b2 || case when v_m2 like '%fn_recibo_anular(-3300010,%' then '/anular' else '' end
                       || case when v_m2 not like '%no hace falta hacer más%' then '/sin_no_hace_falta' else '' end,
                  r.estado,
                  -- La lista de la app (pintarMateriales): no anulado, y sin foto o sin obra.
                  (r.estado is distinct from 'anulado' and (r.estado = 'sin_foto' or r.proyecto_id is null)))
      into v_obt
      from recibos r
     where r.id = -3300010;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (71, 'un repetido sin obra sale de «Por completar» anulándolo, y el 🗑 lo dice', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 72. La fecha de un recibo y de un trabajo externo contabilizados se
--     corrige de diciembre a enero, con los dos meses abiertos (un ticket
--     del 2 de enero leído como del 30 de diciembre): el reverso va en
--     diciembre y el asiento nuevo es NORMAL en enero, porque el papel ya es
--     de enero (el puente lo deja en procedencia.fecha_documento y c2 lo
--     mira). Antes: MX007 para siempre, y el arreglo a mano lo sacaba de los
--     dos años. Con el reloj fingido.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_dicd  date;
  v_ened  date;
  v_obt   text;
  v_esp   text;
begin
  if v_desde is not null then
    select p.desde into v_dicd from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int, 12, 1);
    select p.desde into v_ened from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int + 1, 1, 1);
  end if;
  v_esp := format('recibos: reverso=%1$s/normal nuevo=%3$s/normal/sustituye estado=contabilizado | '
                  'trabajos_externos: reverso=%2$s/normal nuevo=%3$s/normal/sustituye estado=contabilizado reversos=t',
                  v_dicd + 29, v_dicd + 30, v_ened + 1);
  if v_obra is null or v_dicd is null or v_ened is null then
    insert into _pruebas values (72, 'de diciembre a enero, con diciembre abierto: reverso en diciembre y asiento normal en enero',
                                 v_esp, 'omitida: falta obra, o el diciembre y el enero abiertos', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_fingir_hoy(v_ened + 3);   -- «hoy» es el 4 de enero; diciembre y enero, abiertos
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300020, 'total', '100.00', 'fecha', (v_dicd + 29)::text,
                                                 'creado', (v_ened + 2)::text || ' 10:00-05'));
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, costo, externo_id) overriding system value
    values (-3300021, v_obra, 'c3-pruebas zanja subcontratada', v_dicd + 30, 'ajuste', 500.00, -3900001);
    update recibos set fecha = v_ened + 1 where id = -3300020;
    update trabajos_externos set fecha = v_ened + 1 where id = -3300021;
    select string_agg(format('%s: reverso=%s nuevo=%s estado=%s', t.tabla,
                             coalesce((select r.fecha_contable || '/' || r.tipo || coalesce('/' || r.afecta_periodo, '')
                                         from asientos r where r.reversa_a = o.id and r.camino = 'reverso'), '-'),
                             coalesce((select s.fecha_contable || '/' || s.tipo
                                              || case when s.sustituye_a = o.id then '/sustituye' else '' end
                                         from asientos s where s.id = pg_temp.c3_vivo(t.tabla, t.id)), '-'),
                             coalesce((select d.estado || coalesce('/' || d.codigo, '') from puente_documentos d
                                        where d.tabla = t.tabla and d.documento_id = t.id), '-')), ' | ' order by t.tabla)
           || ' reversos=' || coalesce((select case when v.ok then 't' else 'f' end from fn_verificar_cadena() v
                                        where v.control = 'reversos'), '-')
      into v_obt
      from (values ('recibos', '-3300020'), ('trabajos_externos', '-3300021')) t(tabla, id)
      left join lateral (select a.id from asientos a
                          where a.origen_tabla = t.tabla and a.origen_id = t.id and a.camino = 'puente'
                          order by a.cadena_pos limit 1) o on true;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (72, 'de diciembre a enero, con diciembre abierto: reverso en diciembre y asiento normal en enero',
                               v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 73. Lo mismo con diciembre ya CERRADO: el reverso va al primer día de
--     enero como ajuste de diciembre (c2: el reverso de un ejercicio
--     anterior), y el asiento nuevo, normal en enero (el papel es de
--     enero). Nada queda en error, y los dos años dicen lo que es de cada
--     uno. Con el reloj fingido.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_dic   text;
  v_dicd  date;
  v_ened  date;
  v_obt   text;
  v_esp   text;
begin
  if v_desde is not null then
    select p.periodo, p.desde into v_dic, v_dicd from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int, 12, 1);
    select p.desde into v_ened from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int + 1, 1, 1);
  end if;
  v_esp := format('recibos: reverso=%1$s/ajuste_cpa/%2$s nuevo=%3$s/normal/sustituye estado=contabilizado | '
                  'trabajos_externos: reverso=%1$s/ajuste_cpa/%2$s nuevo=%3$s/normal/sustituye estado=contabilizado reversos=t',
                  v_ened, v_dic, v_ened + 1);
  if v_obra is null or v_dic is null or v_ened is null then
    insert into _pruebas values (73, 'de diciembre (cerrado) a enero: reverso como ajuste de diciembre y asiento normal en enero',
                                 v_esp, 'omitida: falta obra, o el diciembre y el enero abiertos', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_fingir_hoy(v_ened + 3);   -- «hoy» es el 4 de enero
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300030, 'total', '100.00', 'fecha', (v_dicd + 29)::text,
                                                 'creado', (v_ened + 2)::text || ' 10:00-05'));
    insert into trabajos_externos (id, proyecto_id, descripcion, fecha, tipo, costo, externo_id) overriding system value
    values (-3300031, v_obra, 'c3-pruebas zanja subcontratada', v_dicd + 30, 'ajuste', 500.00, -3900001);
    perform pg_temp.c3_cerrar_hasta(v_dic);   -- diciembre, cerrado
    update recibos set fecha = v_ened + 1 where id = -3300030;
    update trabajos_externos set fecha = v_ened + 1 where id = -3300031;
    select string_agg(format('%s: reverso=%s nuevo=%s estado=%s', t.tabla,
                             coalesce((select r.fecha_contable || '/' || r.tipo || coalesce('/' || r.afecta_periodo, '')
                                         from asientos r where r.reversa_a = o.id and r.camino = 'reverso'), '-'),
                             coalesce((select s.fecha_contable || '/' || s.tipo
                                              || case when s.sustituye_a = o.id then '/sustituye' else '' end
                                         from asientos s where s.id = pg_temp.c3_vivo(t.tabla, t.id)), '-'),
                             coalesce((select d.estado || coalesce('/' || d.codigo, '') from puente_documentos d
                                        where d.tabla = t.tabla and d.documento_id = t.id), '-')), ' | ' order by t.tabla)
           || ' reversos=' || coalesce((select case when v.ok then 't' else 'f' end from fn_verificar_cadena() v
                                        where v.control = 'reversos'), '-')
      into v_obt
      from (values ('recibos', '-3300030'), ('trabajos_externos', '-3300031')) t(tabla, id)
      left join lateral (select a.id from asientos a
                          where a.origen_tabla = t.tabla and a.origen_id = t.id and a.camino = 'puente'
                          order by a.cadena_pos limit 1) o on true;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (73, 'de diciembre (cerrado) a enero: reverso como ajuste de diciembre y asiento normal en enero',
                               v_esp, coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 74. El devengo ESTÁNDAR no cuenta dos veces lo que la nómina ya pagó. Un
--     devengo hecho antes de que llegue el journal del mes sale en rojo en
--     cuanto el journal llega (control devengo), y volver a devengar lo
--     deshace; con journal en el mes, devengar se niega (MX008). El 5000 del
--     mes queda en lo que pagó el journal, no el doble. Antes: 5000 doble y
--     2210 con sueldos ya pagados, con los controles en verde.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_sig    text := nullif(current_setting('mx3.sig', true), '');
  v_mo     text := fn_puente_cuenta_de('mano_obra');
  v_r1     jsonb;
  v_c1     text;
  v_r2     jsonb;
  v_c2     text;
  v_r3     text;
  v_obt    text;
  v_esp    text := 'primero=posteado control=f/convive deshacer=reversado control=t otra_vez=MX008/nomina mes=240.00 siguiente=0.00';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null or v_sig is null then
    insert into _pruebas values (74, 'el devengo estándar no cuenta dos veces lo que la nómina ya pagó', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra, o el mes abierto y el siguiente', null);
    return;
  end if;
  begin
    insert into costos_equipo (usuario_id, costo_hora) values (v_equipo, 30.00)
    on conflict (usuario_id) do update set costo_hora = 30.00;
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas, co)
    values (-3300040, v_desde + 11, v_equipo, v_obra, 8.0, 'c3-pruebas', 'C3-NOM');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 11, v_desde + 11);
    v_r1 := fn_horas_devengar(v_mes);
    execute 'reset role';
    -- El journal del proveedor de nómina de esas horas (como lo postea f11).
    perform fn_postear_interno(jsonb_build_object(
      'camino', 'puente', 'fecha', to_char(v_desde + 14, 'YYYY-MM-DD'), 'origen_tabla', 'nomina_corridas',
      'origen_id', 'c3-pruebas-74', 'descripcion', 'c3-pruebas: nómina de la semana (journal del proveedor, se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_mo, 'monto', '240.00', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '-240.00'))));
    select case when c.ok then 't' else 'f' end
           || case when c.detalle::text like '%convive con el journal de nómina%' then '/convive' else '' end
      into v_c1
      from fn_puentes_verificar() c where c.control = 'devengo';
    execute 'set local role authenticated';
    v_r2 := fn_horas_devengar(v_mes);
    execute 'reset role';
    select case when c.ok then 't' else 'f' end into v_c2 from fn_puentes_verificar() c where c.control = 'devengo';
    execute 'set local role authenticated';
    begin
      perform fn_horas_devengar(v_mes);
      v_r3 := 'entró';
    exception when others then
      v_r3 := sqlstate || case when sqlerrm like '%journal de nómina%' then '/nomina' else '' end;
    end;
    execute 'reset role';
    v_obt := format('primero=%s control=%s deshacer=%s control=%s otra_vez=%s mes=%s siguiente=%s',
                    v_r1->>'accion', v_c1, v_r2->>'accion', v_c2, v_r3,
                    (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                      where a.periodo = v_mes and l.cuenta = v_mo and l.proyecto_id = v_obra),
                    (select coalesce(sum(l.monto), 0) from asiento_lineas l join asientos a on a.id = l.asiento_id
                      where a.periodo = v_sig and l.cuenta = v_mo and l.proyecto_id = v_obra));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (74, 'el devengo estándar no cuenta dos veces lo que la nómina ya pagó', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 75. Anular una factura cuya retención se reclasificó a mano contra su
--     partida (Dr 1120 / Cr 1110, como piden la guarda y fn_cobro_registrar):
--     la nota de crédito salda la partida COMO ESTÁ HOY, cuenta por cuenta
--     (1110 y 1120 en cero). Si otro asiento movió la partida contra otra
--     cuenta (un castigo a incobrables), la nota no lo deshace: MX008, y el
--     mensaje nombra ese asiento. Y una anulada con saldo en una cuenta y lo
--     contrario en la otra (suma cero) no «cuadra»: el control partidas y
--     facturas_cobro la ven, cuenta por cuenta.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cxc   text := fn_puente_cuenta_de('cxc');
  v_ret   text := fn_puente_cuenta_de('retencion_cxc');
  v_anio  int;
  v_nc    text;
  v_cas   text;
  v_r     jsonb;
  v_c     text;
  v_m     text;
  v_uno   text;
  v_obt   text;
  v_esp   text;
begin
  if v_desde is not null then
    v_anio := extract(year from v_desde + 6)::int;
    v_nc := format('NC-%s-%s', v_anio,
                   lpad((coalesce((select c.ultimo from contadores c where c.serie = 'notas_credito-' || v_anio), 0) + 1)::text, 4, '0'));
  end if;
  v_esp := format('nota=%s saldos=0.00/0.00 aviso=anulada partidas=t castigo=MX008/nombra reclasificada_despues=f/con_saldo', v_nc);
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (75, 'la nota de crédito salda la partida como está hoy, cuenta por cuenta', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3300050, v_obra, 'C3-3350', v_desde + 2, 8000.00, 0),
           (-3300051, v_obra, 'C3-3351', v_desde + 2, 5000.00, 0);
    perform fn_postear(jsonb_build_object('fecha', to_char(v_desde + 5, 'YYYY-MM-DD'),
      'descripcion', 'c3-pruebas: reclasifico la retención de la C3-3350 (se deshace)',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', v_ret, 'monto', '800.00', 'proyecto_id', v_obra, 'partida_tabla', 'facturas', 'partida_id', '-3300050'),
        jsonb_build_object('cuenta', v_cxc, 'monto', '-800.00', 'proyecto_id', v_obra, 'partida_tabla', 'facturas', 'partida_id', '-3300050'))));
    v_cas := fn_postear(jsonb_build_object('fecha', to_char(v_desde + 5, 'YYYY-MM-DD'),
      'descripcion', 'c3-pruebas: castigo parcial de la C3-3351 (se deshace)',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', '6980', 'monto', '500.00'),
        jsonb_build_object('cuenta', v_cxc, 'monto', '-500.00', 'proyecto_id', v_obra, 'partida_tabla', 'facturas', 'partida_id', '-3300051'))))->>'numero';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_factura_anular(-3300050, 'c3: el GC la rechazó; se rehace', v_desde + 6);
    begin
      perform fn_factura_anular(-3300051, 'c3: se rehace', v_desde + 6);
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
      v_m := sqlerrm;
    end;
    execute 'reset role';
    select format('nota=%s saldos=%s/%s aviso=%s partidas=%s castigo=%s', coalesce(v_r->>'nota_credito', '-'),
                  pg_temp.c3_saldo(v_cxc, 'facturas', '-3300050'), pg_temp.c3_saldo(v_ret, 'facturas', '-3300050'),
                  case when fc.aviso like 'anulada con la nota de crédito%' then 'anulada' else fc.aviso end,
                  coalesce((select case when v.ok then 't' else 'f' end from fn_puentes_verificar() v where v.control = 'partidas'), '-'),
                  v_c || case when v_m like '%' || v_cas || '%' then '/nombra' else '' end)
      into v_uno
      from facturas_cobro fc where fc.id = -3300050;
    -- Después de anulada, alguien reclasifica otra vez a mano: 1110 −100 y
    -- 1120 +100 (la suma, cero).
    perform fn_postear(jsonb_build_object('fecha', to_char(v_desde + 7, 'YYYY-MM-DD'),
      'descripcion', 'c3-pruebas: reclasificación sobre una anulada (se deshace)',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', v_ret, 'monto', '100.00', 'proyecto_id', v_obra, 'partida_tabla', 'facturas', 'partida_id', '-3300050'),
        jsonb_build_object('cuenta', v_cxc, 'monto', '-100.00', 'proyecto_id', v_obra, 'partida_tabla', 'facturas', 'partida_id', '-3300050'))));
    select v_uno || format(' reclasificada_despues=%s/%s',
                           coalesce((select case when v.ok then 't' else 'f' end from fn_puentes_verificar() v
                                      where v.control = 'partidas' and v.detalle::text like '%C3-3350 está anulada y tiene%'), 't'),
                           case when fc.aviso like 'anulada y con saldo en el libro%' then 'con_saldo' else fc.aviso end)
      into v_obt
      from facturas_cobro fc where fc.id = -3300050;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (75, 'la nota de crédito salda la partida como está hoy, cuenta por cuenta', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 76. Un ✎ que deja al recibo SIN REGLA (el proveedor escrito con otro
--     nombre, una categoría nueva): su asiento vivo NO se reversa a nada. Se
--     queda (la deuda y el costo siguen siendo reales), el papel sale en la
--     bandeja como aviso con lo que falta, y el control documentos dice que
--     está retenido. Cuando Edgar arregla la regla, fn_puentes_correr hace
--     el reverso y el asiento nuevo. Antes: reverso suelto, la deuda con el
--     proveedor desaparecía y el recibo esperaba sin asiento.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_cxp   text := fn_puente_cuenta_de('cxp');
  v_f     jsonb;
  v_uno   text;
  v_obt   text;
  v_esp   text := 'retenidos=1/0:contabilizado/proveedor 1/0:contabilizado/categoria deuda=-300.00 documentos=f/retenido bandeja=2 '
                  'arreglado=3/1 3/1 deuda=-300.00';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (76, 'un ✎ que deja al recibo sin regla no reversa su asiento: espera la regla', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300060, 'total', '300.00', 'metodo_pago', 'c3 pruebas cuenta'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300061, 'total', '150.00'));
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set proveedor = 'C3 Pruebas Supplies LLC' where id = -3300060;
    update recibos set categoria = 'c3 pruebas herramienta nueva' where id = -3300061;
    execute 'reset role';
    select format('retenidos=%s:%s %s:%s deuda=%s documentos=%s bandeja=%s',
                  pg_temp.c3_cuantos('recibos', '-3300060'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3300060'), '-'),
                  pg_temp.c3_cuantos('recibos', '-3300061'),
                  coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                             where d.tabla = 'recibos' and d.documento_id = '-3300061'), '-'),
                  pg_temp.c3_saldo(v_cxp, 'recibos', '-3300060'),
                  coalesce((select case when v.ok then 't' else 'f' end
                                   || case when v.detalle::text like '%recibos -3300060 cambió y su asiento%se quedó como estaba%'
                                           then '/retenido' else '' end
                              from fn_puentes_verificar() v where v.control = 'documentos'), '-'),
                  (select count(*) from puentes_bandeja b
                    where b.tabla = 'recibos' and b.documento_id in ('-3300060', '-3300061') and b.estado = 'aviso'))
      into v_uno;
    -- Edgar arregla las reglas: el nombre nuevo es del mismo proveedor, y la
    -- categoría nueva tiene su cuenta. El backfill hace lo que faltaba.
    perform fn_proveedor_alias((v_f->>'proveedor')::uuid, 'C3 Pruebas Supplies LLC');
    perform fn_mapeo_categoria('c3 pruebas herramienta nueva', current_setting('mx3.material'));
    perform fn_puentes_correr();
    v_obt := v_uno || format(' arreglado=%s %s deuda=%s', pg_temp.c3_cuantos('recibos', '-3300060'),
                             pg_temp.c3_cuantos('recibos', '-3300061'), pg_temp.c3_saldo(v_cxp, 'recibos', '-3300060'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (76, 'un ✎ que deja al recibo sin regla no reversa su asiento: espera la regla', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 77. El control mano_de_obra no acepta cualquier asiento a mano marcado
--     «reversible»: 5001 (la parte de obra del sueldo de Edgar, solo del
--     journal) y 5000 pagados del banco salen en rojo. El devengo de
--     fn_horas_devengar (5000 contra 2210) sigue valiendo.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mes    text := nullif(current_setting('mx3.mes', true), '');
  v_a1     text;
  v_a2     text;
  v_dev    text;
  v_ok     boolean;
  v_det    jsonb;
  v_obt    text;
  v_esp    text := 'ok=f 5001_a_mano=t 5000_a_mano=t devengo=f';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (77, 'mano de obra: un asiento a mano «reversible» no pasa por devengo', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    insert into costos_equipo (usuario_id, costo_hora) values (v_equipo, 30.00)
    on conflict (usuario_id) do update set costo_hora = 30.00;
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas, co)
    values (-3300070, v_desde + 11, v_equipo, v_obra, 8.0, 'c3-pruebas', 'C3-MO');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 11, v_desde + 11);
    perform fn_horas_devengar(v_mes);
    execute 'reset role';
    v_a1 := fn_postear(jsonb_build_object('fecha', to_char(v_desde + 14, 'YYYY-MM-DD'), 'reversible', true,
      'descripcion', 'c3-pruebas: pago a Edgar por la obra (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('mano_obra_oficial'), 'monto', '1500.00',
                                                     'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '-1500.00'))))->>'numero';
    v_a2 := fn_postear(jsonb_build_object('fecha', to_char(v_desde + 14, 'YYYY-MM-DD'), 'reversible', true,
      'descripcion', 'c3-pruebas: mano de obra pagada en efectivo (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', fn_puente_cuenta_de('mano_obra'), 'monto', '800.00',
                                                     'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '-800.00'))))->>'numero';
    v_dev := (select a.numero from asientos a where a.id = pg_temp.c3_vivo('horas_devengo', v_mes));
    select c.ok, c.detalle->'asientos' into v_ok, v_det from fn_puentes_verificar() c where c.control = 'mano_de_obra';
    v_obt := format('ok=%s 5001_a_mano=%s 5000_a_mano=%s devengo=%s', case when v_ok then 't' else 'f' end,
                    coalesce(v_det ? v_a1, false), coalesce(v_det ? v_a2, false), coalesce(v_det ? v_dev, false));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (77, 'mano de obra: un asiento a mano «reversible» no pasa por devengo', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 78. El MISMO ticket subido dos veces (otro envío, otra llave; el mismo
--     proveedor, número y total, escritos distinto): el segundo no entra,
--     espera en la bandeja (duplicado) y el motivo nombra al otro y dice
--     cómo anularlo. Si Edgar confirma que son dos compras, entra. Y si dos
--     recibos YA contabilizados resultan ser el mismo ticket, el control
--     duplicados se pone en rojo. Antes: al empleado se le debía el doble.
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_autor  uuid;
  v_uno    text;
  v_obt    text;
  v_esp    text := 'segundo=pendiente/duplicado nombra=t bandeja=t asientos=0/0 confirmado=contabilizado control=t '
                   'editado=contabilizado/duplicado control=f/los_dos';
begin
  v_autor := coalesce(v_equipo, v_dueno);
  if v_autor is null or v_obra is null or v_desde is null then
    insert into _pruebas values (78, 'el mismo ticket dos veces: el segundo espera (duplicado); el control lo ve', v_esp,
                                 'omitida: falta alguien, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300089, 'total', '212.40', 'metodo_pago', 'c3 pruebas reembolso',
                                                 'autor_id', v_autor, 'proveedor', 'Home Depot c3', 'num_recibo', 'HD-4471-0092'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300088, 'total', '212.40', 'metodo_pago', 'c3 pruebas reembolso',
                                                 'autor_id', v_autor, 'proveedor', 'HOME DEPOT C3', 'num_recibo', 'hd 4471 0092'));
    select format('segundo=%s nombra=%s bandeja=%s asientos=%s',
                  coalesce(d.estado || '/' || d.codigo, '-'),
                  coalesce(d.motivo like '%recibo -3300089%' and d.motivo like '%fn_recibo_anular(-3300088,%', false),
                  exists (select 1 from puentes_bandeja b
                           where b.tabla = 'recibos' and b.documento_id = '-3300088' and b.estado = 'pendiente'),
                  pg_temp.c3_cuantos('recibos', '-3300088'))
      into v_uno
      from (select 1) x
      left join puente_documentos d on d.tabla = 'recibos' and d.documento_id = '-3300088';
    perform fn_puentes_confirmar('recibos', -3300088, 'duplicado', 'c3: dos compras iguales el mismo día');
    v_uno := v_uno || format(' confirmado=%s control=%s',
                             coalesce((select d.estado from puente_documentos d
                                        where d.tabla = 'recibos' and d.documento_id = '-3300088'), '-'),
                             coalesce((select case when v.ok then 't' else 'f' end from fn_puentes_verificar() v
                                        where v.control = 'duplicados'), '-'));
    -- Otro recibo, ya contabilizado, que se corrige y resulta el mismo ticket.
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300087, 'total', '212.40', 'metodo_pago', 'c3 pruebas reembolso',
                                                 'autor_id', v_autor, 'proveedor', 'Otro c3', 'num_recibo', 'X-1'));
    update recibos set proveedor = 'Home Depot c3', num_recibo = 'HD-4471-0092' where id = -3300087;
    v_obt := v_uno || format(' editado=%s control=%s',
                             coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                                        where d.tabla = 'recibos' and d.documento_id = '-3300087'), '-'),
                             coalesce((select case when v.ok then 't' else 'f' end
                                              || case when v.detalle::text like '%recibo -3300089%recibo -3300087%' then '/los_dos' else '' end
                                         from fn_puentes_verificar() v where v.control = 'duplicados'), '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (78, 'el mismo ticket dos veces: el segundo espera (duplicado); el control lo ve', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 79. facturas_cobro no cuenta el DESCUENTO como dinero cobrado: un cobro de
--     7,600.00 con 400.00 de descuento a una factura de 8,000.00 da
--     cobrado_libro 7,600.00 (lo que casa con el banco) y el descuento en su
--     columna; con la casilla de la app marcada (cobrado 8,000.00), el aviso
--     no dice «cuadra».
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_obt   text;
  v_esp   text := 'app=8000.00 libro=7600.00 descuento=400.00 saldo=0.00 aviso=con_descuento';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (79, 'facturas_cobro: el descuento no es dinero cobrado', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3300090, v_obra, 'C3-3390', v_desde + 2, 8000.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 10)::text, 'monto', '7600.00', 'medio', 'cheque',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -3300090, 'monto', '7600.00',
                                                                   'descuento', '400.00'))));
    update facturas set pagada = true where id = -3300090;
    execute 'reset role';
    select format('app=%s libro=%s descuento=%s saldo=%s aviso=%s', fc.cobrado_app, fc.cobrado_libro, fc.descuento_libro,
                  fc.saldo_libro, case when fc.aviso like 'cobrada en el libro con descuento%' then 'con_descuento' else fc.aviso end)
      into v_obt
      from facturas_cobro fc where fc.id = -3300090;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (79, 'facturas_cobro: el descuento no es dinero cobrado', v_esp, coalesce(v_obt, '-'),
                               coalesce(v_obt = v_esp, false));
end $$;

-- 80. El IMPUESTO: un recibo cuyo subtotal + tax no es su total (la lectura
--     tomó el total sin el impuesto) no entra callado: espera en la bandeja
--     (impuesto) con los tres números. Si Edgar confirma que el total es lo
--     que se pagó, entra, y la procedencia lo dice. «Incluido en el total»
--     solo se escribe cuando se comprobó; sin tax, «no se pudo comprobar».
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_uno   text;
  v_obt   text;
  v_esp   text := 'no_cuadra=pendiente/impuesto cuadra=incluido sin_tax=no_se_pudo confirmado=contabilizado/confirmo';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (80, 'impuesto: subtotal + tax que no es el total espera; «incluido» solo si se comprobó', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300100, 'total', '200.00', 'subtotal', '200.00', 'tax', '14.00'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300101, 'total', '107.00', 'subtotal', '100.00', 'tax', '7.00'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300102, 'total', '60.00'));
    v_uno := coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                        where d.tabla = 'recibos' and d.documento_id = '-3300100'), '-');
    perform fn_puentes_confirmar('recibos', -3300100, 'impuesto', 'c3: el total del ticket es lo que se pagó (descuento en caja)');
    select format('no_cuadra=%s cuadra=%s sin_tax=%s confirmado=%s', v_uno,
                  coalesce((select case when a.procedencia->>'impuesto'
                                             like '%incluido en el total (subtotal 100.00 + tax 7.00 = total 107.00)%'
                                        then 'incluido' else a.procedencia->>'impuesto' end
                              from asientos a where a.id = pg_temp.c3_vivo('recibos', '-3300101')), '-'),
                  coalesce((select case when a.procedencia->>'impuesto' like '%no se pudo comprobar%'
                                        then 'no_se_pudo' else a.procedencia->>'impuesto' end
                              from asientos a where a.id = pg_temp.c3_vivo('recibos', '-3300102')), '-'),
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300100'), '-')
                  || coalesce((select case when a.procedencia->>'impuesto' like '%Edgar confirmó%' then '/confirmo' else '/no_dice' end
                                 from asientos a where a.id = pg_temp.c3_vivo('recibos', '-3300100')), ''))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (80, 'impuesto: subtotal + tax que no es el total espera; «incluido» solo si se comprobó', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 81. Una DEVOLUCIÓN (la marca que la app pone en las notas) con el total en
--     positivo no entra como compra: espera (devolucion). Con el total en
--     negativo entra como devolución. Si Edgar confirma que el positivo era
--     una compra, entra como compra.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_mat   text := current_setting('mx3.material', true);
  v_uno   text;
  v_obt   text;
  v_esp   text := 'positiva=pendiente/devolucion negativa=contabilizado:-45.99 confirmada=contabilizado:45.99';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (81, 'una DEVOLUCIÓN con total positivo espera; con negativo entra como devolución', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300110, 'total', '45.99', 'notas', 'DEVOLUCIÓN — breaker equivocado'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300111, 'total', '-45.99', 'notas', 'DEVOLUCIÓN — breaker equivocado'));
    v_uno := coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                        where d.tabla = 'recibos' and d.documento_id = '-3300110'), '-');
    perform fn_puentes_confirmar('recibos', -3300110, 'devolucion', 'c3: es una compra; la nota se quedó de otro ticket');
    select format('positiva=%s negativa=%s:%s confirmada=%s:%s', v_uno,
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300111'), '-'),
                  coalesce((select l.monto::text from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('recibos', '-3300111') and l.cuenta = v_mat), '-'),
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300110'), '-'),
                  coalesce((select l.monto::text from asiento_lineas l
                             where l.asiento_id = pg_temp.c3_vivo('recibos', '-3300110') and l.cuenta = v_mat), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (81, 'una DEVOLUCIÓN con total positivo espera; con negativo entra como devolución', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 82. Las REGLAS: dos papeles del puente no comparten cuenta (sueldos
--     devengados o use tax en 2010 → MX004); una categoría no carga al
--     banco, a la cuenta por cobrar ni a la depreciación acumulada (MX004),
--     y sí a la bodega (un activo que se compra); una tarjeta no va a la
--     cuenta de otro papel (MX004). Y una regla así escrita con la guarda
--     apagada (de antes de este parche) la ve el control reglas.
do $$
declare
  v_cxp   text := fn_puente_cuenta_de('cxp');
  v_a     text;
  v_b     text;
  v_c     text;
  v_d     text;
  v_e     text;
  v_g     text;
  v_h     text;
  v_ctl   text;
  v_omite text;
  v_obt   text;
  v_esp   text := 'sueldos_en_cxp=MX004 use_tax_en_cxp=MX004 categoria_banco=MX004 categoria_cxc=MX004 '
                  'categoria_depreciacion=MX004 categoria_bodega=ok tarjeta_en_sueldos=MX004 guarda_apagada=f/dos_papeles';
begin
  if v_cxp is null then
    insert into _pruebas values (82, 'reglas: cada papel con su cuenta; una categoría compra algo', v_esp,
                                 'omitida: faltan las cuentas del puente', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    begin
      update puente_cuentas set cuenta = v_cxp where rol = 'sueldos_devengados';
      v_a := 'entró';
    exception when others then
      v_a := sqlstate;
    end;
    begin
      perform fn_puentes_cuenta('use_tax', v_cxp);
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    begin
      perform fn_mapeo_categoria('c3 pruebas al banco', fn_puente_cuenta_de('banco'));
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
    end;
    begin
      perform fn_mapeo_categoria('c3 pruebas a cobrar', fn_puente_cuenta_de('cxc'));
      v_d := 'entró';
    exception when others then
      v_d := sqlstate;
    end;
    begin
      perform fn_mapeo_categoria('c3 pruebas depreciacion',
                                 (select c.codigo from cuentas c
                                   where c.tipo = 'activo' and c.saldo_normal = 'haber' and c.activa and c.imputable
                                   order by (c.codigo = '1590') desc, c.codigo limit 1));
      v_e := 'entró';
    exception when others then
      v_e := sqlstate;
    end;
    begin
      perform fn_mapeo_categoria('c3 pruebas bodega',
                                 (select c.codigo from cuentas c
                                   where c.tipo = 'activo' and c.saldo_normal = 'debe' and left(c.codigo, 2) = '13'
                                     and c.activa and c.imputable
                                   order by (c.codigo = '1300') desc, c.codigo limit 1));
      v_g := 'ok';
    exception when others then
      v_g := sqlstate;
    end;
    begin
      perform fn_tarjeta_alta('9990', fn_puente_cuenta_de('sueldos_devengados'), 'c3-pruebas');
      v_h := 'entró';
    exception when others then
      v_h := sqlstate;
    end;
    -- Con la guarda apagada un instante (si la tabla está en uso, omitida).
    -- Solo si la guarda existe: en rojo (bloque A) no hay guarda, el update
    -- entra igual y la prueba sigue y dice qué no pasó.
    if exists (select 1 from pg_trigger
                where tgname = 'trg_puente_cuentas_guarda' and tgrelid = 'public.puente_cuentas'::regclass) then
      execute 'set local lock_timeout = ''2s''';
      begin
        execute 'alter table public.puente_cuentas disable trigger trg_puente_cuentas_guarda';
      exception when lock_not_available then
        v_omite := 'la tabla puente_cuentas estaba en uso (se prueba en el banco)';
        raise exception using errcode = 'MXT00';
      end;
    end if;
    update puente_cuentas set cuenta = v_cxp where rol = 'sueldos_devengados';
    if exists (select 1 from pg_trigger
                where tgname = 'trg_puente_cuentas_guarda' and tgrelid = 'public.puente_cuentas'::regclass) then
      execute 'alter table public.puente_cuentas enable trigger trg_puente_cuentas_guarda';
    end if;
    select case when v.ok then 't' else 'f' end
           || case when v.detalle::text like '%es de dos papeles del puente%' then '/dos_papeles' else '' end
      into v_ctl
      from fn_puentes_verificar() v where v.control = 'reglas';
    v_obt := format('sueldos_en_cxp=%s use_tax_en_cxp=%s categoria_banco=%s categoria_cxc=%s categoria_depreciacion=%s '
                    'categoria_bodega=%s tarjeta_en_sueldos=%s guarda_apagada=%s', v_a, v_b, v_c, v_d, v_e, v_g, v_h,
                    coalesce(v_ctl, '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  if v_omite is not null then
    insert into _pruebas values (82, 'reglas: cada papel con su cuenta; una categoría compra algo', v_esp, 'omitida: ' || v_omite, null);
  else
    insert into _pruebas values (82, 'reglas: cada papel con su cuenta; una categoría compra algo', v_esp, coalesce(v_obt, '-'),
                                 coalesce(v_obt = v_esp, false));
  end if;
end $$;

-- 83. El ✎ de la app sobre un recibo ANULADO (manda total + estado 'leido'
--     + nota) no lo des-anula: la nota se guarda, el recibo sigue anulado y
--     no hay asiento nuevo. Des-anular es a propósito, con
--     fn_recibo_desanular y su motivo: el asiento nuevo sustituye al que se
--     reversó y dice qué cambió («estado: anulado → leido») y por qué.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_orig  uuid;
  v_uno   text;
  v_obt   text;
  v_esp   text := 'anulado=2/1 lapiz=anulado/2/1/nota_guardada desanular=leido/3/1 sustituye=t cambios=estado: anulado → leido motivo=t';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (83, 'el ✎ no des-anula un recibo; fn_recibo_desanular sí, con su rastro', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300130, 'total', '50.00'));
    v_orig := pg_temp.c3_vivo('recibos', '-3300130');
    perform fn_recibo_anular(-3300130, 'c3: parecía repetido');
    v_uno := 'anulado=' || pg_temp.c3_cuantos('recibos', '-3300130');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    -- Lo que manda el ✎ (js/app.js, .btn-recibo-total) cada vez que hay total.
    update recibos set total = 50.00, estado = 'leido', proveedor = 'C3 PRUEBAS SUPPLY', notas = 'c3: DUPLICADO del otro'
     where id = -3300130;
    execute 'reset role';
    select v_uno || format(' lapiz=%s/%s%s', r.estado, pg_temp.c3_cuantos('recibos', '-3300130'),
                           case when r.notas = 'c3: DUPLICADO del otro' then '/nota_guardada' else '' end)
      into v_uno
      from recibos r where r.id = -3300130;
    perform fn_recibo_desanular(-3300130, 'c3: no era repetido, son dos compras');
    select v_uno || format(' desanular=%s/%s sustituye=%s cambios=%s motivo=%s', r.estado, pg_temp.c3_cuantos('recibos', '-3300130'),
                           coalesce(a.sustituye_a = v_orig, false), coalesce(a.procedencia->>'cambios', '-'),
                           coalesce(a.procedencia->>'motivo_edgar' = 'c3: no era repetido, son dos compras', false))
      into v_obt
      from recibos r
      left join asientos a on a.id = pg_temp.c3_vivo('recibos', '-3300130')
     where r.id = -3300130;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (83, 'el ✎ no des-anula un recibo; fn_recibo_desanular sí, con su rastro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 84. La FECHA LEÍDA contra el día en que se subió: una fecha de más de un
--     día después de la subida (¿mes y día cruzados?) espera
--     (fecha_posterior_a_subida) hasta que Edgar la corrija o la confirme;
--     un recibo SUBIDO antes del corte es de antes del corte aunque la
--     lectura diga octubre (no entra al libro nuevo); un día de margen (la
--     hora de la tienda) entra sin preguntar.
do $$
declare
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_corte date := fn_puente_corte();
  v_uno   text;
  v_obt   text;
  v_esp   text := 'posterior=pendiente/fecha_posterior_a_subida confirmada=contabilizado subido_antes=no_aplica/antes_del_corte/mal_leida '
                  'margen=contabilizado';
begin
  if v_obra is null or v_desde is null then
    insert into _pruebas values (84, 'fecha leída posterior a la subida: se pregunta; subido antes del corte: no entra', v_esp,
                                 'omitida: falta obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    -- Subido el 10-oct, la lectura dice 10-nov.
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300140, 'total', '75.00', 'fecha', (v_desde + 40)::text,
                                                 'creado', (v_desde + 9)::text || ' 10:00-04'));
    -- Subido el 11-ago (antes del corte), la lectura dice 8-oct (un «08/10»).
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300141, 'total', '64.00', 'fecha', (v_desde + 7)::text,
                                                 'creado', (v_corte - 51)::text || ' 10:00-04'));
    -- Subido el 11-oct por la noche, la lectura dice 12-oct: un día de margen.
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300142, 'total', '33.00', 'fecha', (v_desde + 11)::text,
                                                 'creado', (v_desde + 10)::text || ' 22:00-04'));
    v_uno := coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                        where d.tabla = 'recibos' and d.documento_id = '-3300140'), '-');
    perform fn_puentes_confirmar('recibos', -3300140, 'fecha_posterior_a_subida', 'c3: el ticket es del 10-nov, se subió antes');
    select format('posterior=%s confirmada=%s subido_antes=%s margen=%s', v_uno,
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300140'), '-'),
                  coalesce((select d.estado || '/' || d.codigo || case when d.motivo like '%mal leída%' then '/mal_leida' else '' end
                              from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300141'), '-'),
                  coalesce((select d.estado from puente_documentos d where d.tabla = 'recibos' and d.documento_id = '-3300142'), '-'))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (84, 'fecha leída posterior a la subida: se pregunta; subido antes del corte: no entra', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 85. Una CUENTA retirada como dice c1 (la tarjeta se pagó y se cerró: sin
--     saldo, inactiva): cambiarle la foto a un recibo viejo de ella no lo
--     saca del libro (su asiento se queda, con el aviso en la bandeja), y
--     anularlo se niega antes de tocar nada (MX008): un reverso dejaría en
--     ella un saldo que nadie podría mover. El control cuentas_inactivas ve
--     una cuenta inactiva con saldo vivo.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_pago  uuid;
  v_foto  text;
  v_an    text;
  v_c1    text;
  v_obt   text;
  v_esp   text := 'foto=1/0:contabilizado/cuenta saldo=0.00 anular=MX008 control=t tras_reverso=f';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (85, 'una cuenta retirada: el recibo viejo no sale del libro ni deja saldo atrapado', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('2100-9997', 'c3-pruebas: tarjeta que se cierra', 'c3 closed card', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
    on conflict (codigo) do nothing;
    perform fn_tarjeta_alta('9997', '2100-9997', 'c3-pruebas: tarjeta que se cierra');
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300150, 'total', '120.00', 'ultimos4', '9997'));
    v_pago := (fn_postear(jsonb_build_object('fecha', to_char(v_desde + 20, 'YYYY-MM-DD'),
      'descripcion', 'c3-pruebas: se paga la tarjeta 9997 y se cierra (se deshace)',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2100-9997', 'monto', '120.00'),
                                  jsonb_build_object('cuenta', current_setting('mx3.banco'), 'monto', '-120.00'))))->>'id')::uuid;
    update cuentas set activa = false where codigo = '2100-9997';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    update recibos set ruta = 'recibos/c3-pruebas/-3300150-bis.jpg' where id = -3300150;
    begin
      perform fn_recibo_anular(-3300150, 'c3: repetido');
      v_an := 'entró';
    exception when others then
      v_an := sqlstate;
    end;
    execute 'reset role';
    v_foto := pg_temp.c3_cuantos('recibos', '-3300150') || ':'
              || coalesce((select d.estado || '/' || d.codigo from puente_documentos d
                            where d.tabla = 'recibos' and d.documento_id = '-3300150'), '-');
    select case when v.ok then 't' else 'f' end into v_c1 from fn_puentes_verificar() v where v.control = 'cuentas_inactivas';
    -- Un reverso sí entra en una cuenta inactiva (no se juzga contra el plan
    -- de hoy): el del pago deja ahí un saldo, y el control lo ve.
    perform fn_reversar(v_pago, 'c3-pruebas: el pago no era de esta tarjeta');
    v_obt := format('foto=%s saldo=%s anular=%s control=%s tras_reverso=%s', v_foto,
                    (select coalesce(sum(l.monto), 0) from asiento_lineas l where l.cuenta = '2100-9997'
                        and l.asiento_id <> (select r.id from asientos r where r.reversa_a = v_pago)),
                    v_an, coalesce(v_c1, '-'),
                    coalesce((select case when v.ok then 't' else 'f' end from fn_puentes_verificar() v
                               where v.control = 'cuentas_inactivas'), '-'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (85, 'una cuenta retirada: el recibo viejo no sale del libro ni deja saldo atrapado', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 86. Una factura de un año ya CERRADO cuya cuenta de ingreso se retiró
--     (c1 lo deja: su saldo es de un ejercicio cerrado): anularla lo dice en
--     claro antes de numerar la nota (MX004, con el SQL para reactivarla),
--     en vez de un rechazo del libro a medio camino. Con el reloj fingido.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_dic   text;
  v_ened  date;
  v_f     jsonb;
  v_a     text;
  v_m     text;
  v_obt   text;
  v_esp   text := 'anular=MX004/dice_como';
begin
  if v_desde is not null then
    select p.periodo into v_dic from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int, 12, 1);
    select p.desde into v_ened from periodos p
     where p.tipo = 'mes' and p.estado = 'abierto' and p.desde = make_date(extract(year from v_desde)::int + 1, 1, 1);
  end if;
  if v_dueno is null or v_obra is null or v_dic is null or v_ened is null then
    insert into _pruebas values (86, 'anular una factura con su cuenta de ingreso retirada: MX004 en claro', v_esp,
                                 'omitida: falta dueño, obra, o el diciembre y el enero abiertos', null);
    return;
  end if;
  begin
    lock table public.periodos in exclusive mode;
    v_f := pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3300160, v_obra, 'C3-3360', v_desde + 2, 900.00, 0);
    perform pg_temp.c3_cerrar_hasta(v_dic);
    update periodos set estado = 'cerrado', cerrado_el = now()
     where tipo = 'anio' and anio = extract(year from v_desde)::int;
    update cuentas set activa = false where codigo = v_f->>'ingreso';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_factura_anular(-3300160, 'c3: se rehace', v_ened + 4);
      v_a := 'entró';
    exception when others then
      v_a := sqlstate;
      v_m := sqlerrm;
    end;
    execute 'reset role';
    v_obt := 'anular=' || v_a || case when v_m like '%update cuentas set activa = true where codigo in (%' then '/dice_como' else '' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (86, 'anular una factura con su cuenta de ingreso retirada: MX004 en claro', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 87. fn_cobro_registrar lee cada factura_id UNA vez: « -N» y «-N » son la
--     factura -N para el candado y para todo lo demás (antes el candado se
--     saltaba esas y dos cobros a la vez la cobraban dos veces: eso lo
--     prueba c3-concurrencia.sh); lo que no es un número entero → 22023.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_desde date := nullif(current_setting('mx3.desde', true), '')::date;
  v_r1    jsonb;
  v_r2    jsonb;
  v_c     text;
  v_d     text;
  v_e     text;
  v_obt   text;
  v_esp   text := 'espacio=-3300170 detras=-3300170 letras=22023 largo=22023 decimal=22023 abierto=500.00';
begin
  if v_dueno is null or v_obra is null or v_desde is null then
    insert into _pruebas values (87, 'cobros: factura_id se lee una vez; lo que no es un entero, 22023', v_esp,
                                 'omitida: falta dueño, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    insert into facturas (id, proyecto_id, num, fecha, monto, retencion) overriding system value
    values (-3300170, v_obra, 'C3-3370', v_desde + 2, 1000.00, 0);
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r1 := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 5)::text, 'monto', '300.00',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', ' -3300170', 'monto', '300.00'))));
    v_r2 := fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 6)::text, 'monto', '200.00',
              'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', '-3300170 ', 'monto', '200.00'))));
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 7)::text, 'monto', '1.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', 'x-3300170', 'monto', '1.00'))));
      v_c := 'entró';
    exception when others then
      v_c := sqlstate;
    end;
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 7)::text, 'monto', '1.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', '99999999999999999999', 'monto', '1.00'))));
      v_d := 'entró';
    exception when others then
      v_d := sqlstate;
    end;
    begin
      perform fn_cobro_registrar(jsonb_build_object('fecha', (v_desde + 7)::text, 'monto', '1.00',
                'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', '-3300170.0', 'monto', '1.00'))));
      v_e := 'entró';
    exception when others then
      v_e := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('espacio=%s detras=%s letras=%s largo=%s decimal=%s abierto=%s',
                    coalesce((select string_agg(ap.factura_id::text, ',') from aplicaciones_cobro ap
                               where ap.cobro_id = (v_r1->>'cobro')::uuid), '-'),
                    coalesce((select string_agg(ap.factura_id::text, ',') from aplicaciones_cobro ap
                               where ap.cobro_id = (v_r2->>'cobro')::uuid), '-'),
                    v_c, v_d, v_e, pg_temp.c3_saldo(fn_puente_cuenta_de('cxc'), 'facturas', '-3300170'));
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (87, 'cobros: factura_id se lee una vez; lo que no es un entero, 22023', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 88. La FOTO de un recibo es suya y nueva. Un trabajador no sube un
--     recibo «por leer» que apunta a la foto de OTRO recibo (la lectura lo
--     volvía a contabilizar, a la obra que él eligiera o como reembolso a su
--     nombre): 42501. Tampoco a un archivo fuera de recibos/ (un documento
--     del dueño), ni a una foto que subió otra persona. La suya, nueva,
--     entra como siempre. Y el 📷 de Edgar no le pone a un recibo la foto de
--     otro (MX003).
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_sto    boolean := to_regclass('storage.objects') is not null;
  v_a      text;
  v_b      text;
  v_c      text;
  v_d      text;
  v_e      text;
  v_obt    text;
  v_esp    text;
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (88, 'la foto de un recibo es suya y nueva (ni la de otro recibo ni la de otro)',
                                 'ajena=42501 fuera_de_recibos=42501 foto_de_otro=42501 propia=ok camara_ajena=MX003',
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    perform pg_temp.c3_montar();
    perform pg_temp.c3_inmediato();
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300180, 'total', '99.00', 'ruta', 'recibos/c3-pruebas/ajena-180.jpg'));
    perform pg_temp.c3_recibo(jsonb_build_object('id', -3300181, 'total', '12.00'));
    -- Una foto que subió el dueño (en el almacén, a su nombre).
    if v_sto then
      begin
        execute 'insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)'
          using 'fotos', 'recibos/c3-pruebas/del-dueno-182.jpg', v_dueno;
      exception when others then
        v_sto := false;
      end;
    end if;
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      insert into recibos (id, proyecto_id, ruta, notas, co, autor_id) overriding system value
      values (-3300183, v_obra, 'recibos/c3-pruebas/ajena-180.jpg', 'c3-pruebas', 'CO-X', v_equipo);
      v_a := 'entró';
    exception when others then
      v_a := sqlstate;
    end;
    begin
      insert into recibos (id, proyecto_id, ruta, notas, co, autor_id) overriding system value
      values (-3300184, v_obra, 'docs/c3-pruebas/contrato.pdf', 'c3-pruebas', 'CO-X', v_equipo);
      v_b := 'entró';
    exception when others then
      v_b := sqlstate;
    end;
    if v_sto then
      begin
        insert into recibos (id, proyecto_id, ruta, notas, co, autor_id) overriding system value
        values (-3300185, v_obra, 'recibos/c3-pruebas/del-dueno-182.jpg', 'c3-pruebas', 'CO-X', v_equipo);
        v_c := 'entró';
      exception when others then
        v_c := sqlstate;
      end;
    else
      v_c := 'sin_storage';
    end if;
    begin
      insert into recibos (id, proyecto_id, ruta, notas, co, autor_id) overriding system value
      values (-3300186, v_obra, 'recibos/c3-pruebas/propia-186.jpg', 'c3-pruebas', 'CO-X', v_equipo);
      v_d := 'ok';
    exception when others then
      v_d := sqlstate;
    end;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update recibos set ruta = 'recibos/c3-pruebas/ajena-180.jpg' where id = -3300181;
      v_e := 'entró';
    exception when others then
      v_e := sqlstate;
    end;
    execute 'reset role';
    v_obt := format('ajena=%s fuera_de_recibos=%s foto_de_otro=%s propia=%s camara_ajena=%s', v_a, v_b, v_c, v_d, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  v_esp := format('ajena=42501 fuera_de_recibos=42501 foto_de_otro=%s propia=ok camara_ajena=MX003',
                  case when v_sto then '42501' else 'sin_storage' end);
  insert into _pruebas values (88, 'la foto de un recibo es suya y nueva (ni la de otro recibo ni la de otro)', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 89. La guarda de horas: un reporte que está (o estuvo) aprobado no cambia
--     de número, ni el equipo renumera uno con su permiso de corrección
--     (MX003). Y si Edgar cambia las horas Y el sello en un solo cambio,
--     quedan escritas las dos cosas (invalidada lo de antes, aprobada lo de
--     ahora).
do $$
declare
  v_dueno  uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_equipo uuid := nullif(current_setting('mx3.equipo', true), '')::uuid;
  v_obra   text := nullif(current_setting('mx3.obra', true), '');
  v_desde  date := nullif(current_setting('mx3.desde', true), '')::date;
  v_a      text;
  v_b      text;
  v_obt    text;
  v_esp    text := 'equipo_renumera=MX003 edgar_renumera_aprobada=MX003 horas_y_sello=aprobada>invalidada>aprobada sigue_aprobada=t horas=6.0';
begin
  if v_dueno is null or v_equipo is null or v_obra is null or v_desde is null then
    insert into _pruebas values (89, 'horas: no se renumeran; horas y sello a la vez quedan escritos', v_esp,
                                 'omitida: falta dueño, alguien del equipo, obra o mes abierto', null);
    return;
  end if;
  begin
    insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas, correccion_estado)
    values (-3300190, v_desde + 26, v_equipo, v_obra, 8.0, 'c3-pruebas', null),
           (-3300191, v_desde + 27, v_equipo, v_obra, 4.0, 'c3-pruebas', 'aprobada');
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_horas_aprobar(v_equipo, v_desde + 26, v_desde + 26);
    execute 'reset role';
    -- El trabajador, con su permiso de corrección, le cambia el número.
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update horas set id = -3300192 where id = -3300191;
      v_a := case when found then 'entró' else 'no_tocó' end;
    exception when others then
      v_a := sqlstate;
    end;
    execute 'reset role';
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      update horas set id = -3300193 where id = -3300190;
      v_b := case when found then 'entró' else 'no_tocó' end;
    exception when others then
      v_b := sqlstate;
    end;
    -- Horas y sello en un solo update (por la API).
    update horas set horas = 6.0, aprobado_por = v_dueno, aprobado_el = clock_timestamp() where id = -3300190;
    execute 'reset role';
    select format('equipo_renumera=%s edgar_renumera_aprobada=%s horas_y_sello=%s sigue_aprobada=%s horas=%s', v_a, v_b,
                  coalesce((select string_agg(a.accion, '>' order by a.hecho_el) from horas_aprobaciones a where a.horas_id = -3300190),
                           '-'),
                  h.aprobado_el is not null, h.horas)
      into v_obt
      from horas h where h.id = -3300190;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  insert into _pruebas values (89, 'horas: no se renumeran; horas y sello a la vez quedan escritos', v_esp,
                               coalesce(v_obt, '-'), coalesce(v_obt = v_esp, false));
end $$;

-- 90. El papel no se MUEVE ni se reemplaza en Storage: con un update del
--     dueño permitido (ESQUEMA-REAL: «Dueño: todo»), mover la foto de un
--     recibo o un documento a otra carpeta (para borrarlos después), o
--     reescribirlos encima, no toca nada; meter otro archivo en recibos/
--     por update, tampoco (42501). Una foto de obra se mueve como hoy, la
--     subida de la app (un insert) sigue igual, y el control papel exige las
--     dos policies. Sin Storage, omitida.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx3.dueno', true), '')::uuid;
  v_obra  text := nullif(current_setting('mx3.obra', true), '');
  v_omite text;
  v_1     bigint;
  v_2     bigint;
  v_3     bigint;
  v_4     bigint;
  v_5     text;
  v_6     bigint;
  v_ctl   text;
  v_sin   text;
  v_obt   text;
  v_esp   text := 'mover_recibo=0 mover_documento=0 reemplazar=0 mover_foto_de_obra=1 meter_en_recibos=42501 subir=1 control=t '
                  'sin_la_policy=f';
begin
  if to_regclass('storage.objects') is null or v_dueno is null or v_obra is null then
    insert into _pruebas values (90, 'el papel no se mueve ni se reemplaza en Storage', v_esp,
                                 'omitida: no hay Storage en esta base (en el banco: 03-storage-simulacro.sql)', null);
    return;
  end if;
  begin
    begin
      execute 'insert into storage.objects (bucket_id, name, owner) values ($1, $2, $5), ($1, $3, $5), ($1, $4, $5)'
        using 'fotos', 'recibos/c3-pruebas/900.jpg', 'docs/c3-pruebas/900.pdf', v_obra || '/c3-pruebas-900.jpg', v_dueno;
      execute 'create policy "c3-pruebas: el dueño edita" on storage.objects for update to authenticated '
              'using (bucket_id = ''fotos'' and public.es_dueno()) with check (bucket_id = ''fotos'' and public.es_dueno())';
    exception when others then
      v_omite := format('no se pudo simular el update del dueño en Storage (%s): se prueba en el banco', sqlstate);
    end;
    if v_omite is null then
      perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      execute 'set local role authenticated';
      execute 'update storage.objects set name = $1 where bucket_id = $2 and name = $3'
        using 'papelera/900.jpg', 'fotos', 'recibos/c3-pruebas/900.jpg';
      get diagnostics v_1 = row_count;
      execute 'update storage.objects set name = $1 where bucket_id = $2 and name = $3'
        using 'papelera/900.pdf', 'fotos', 'docs/c3-pruebas/900.pdf';
      get diagnostics v_2 = row_count;
      execute 'update storage.objects set metadata = $1 where bucket_id = $2 and name = $3'
        using '{"reemplazada": true}'::jsonb, 'fotos', 'recibos/c3-pruebas/900.jpg';
      get diagnostics v_3 = row_count;
      execute 'update storage.objects set name = $1 where bucket_id = $2 and name = $3'
        using v_obra || '/c3-pruebas-900-movida.jpg', 'fotos', v_obra || '/c3-pruebas-900.jpg';
      get diagnostics v_4 = row_count;
      begin
        execute 'update storage.objects set name = $1 where bucket_id = $2 and name = $3'
          using 'recibos/c3-pruebas/901-metida.jpg', 'fotos', v_obra || '/c3-pruebas-900-movida.jpg';
        v_5 := 'entró';
      exception when others then
        v_5 := sqlstate;
      end;
      execute 'insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)'
        using 'fotos', 'recibos/c3-pruebas/902.jpg', v_dueno;
      get diagnostics v_6 = row_count;
      execute 'reset role';
      select case when c.ok then 't' else 'f' end into v_ctl from fn_puentes_verificar() c where c.control = 'papel';
      begin
        execute 'drop policy "el papel no se mueve" on storage.objects';
        select case when c.ok then 't' else 'f' end into v_sin from fn_puentes_verificar() c where c.control = 'papel';
      exception when others then
        v_sin := 'no_se_pudo';
      end;
      v_obt := format('mover_recibo=%s mover_documento=%s reemplazar=%s mover_foto_de_obra=%s meter_en_recibos=%s subir=%s control=%s '
                      'sin_la_policy=%s', v_1, v_2, v_3, v_4, v_5, v_6, coalesce(v_ctl, '-'), coalesce(v_sin, '-'));
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 90);
  end;
  if v_omite is not null then
    insert into _pruebas values (90, 'el papel no se mueve ni se reemplaza en Storage', v_esp, 'omitida: ' || v_omite, null);
  else
    insert into _pruebas values (90, 'el papel no se mueve ni se reemplaza en Storage', v_esp, coalesce(v_obt, '-'),
                                 coalesce(v_obt = v_esp, false));
  end if;
end $$;

-- 91. NO DEJA RASTRO: todo lo de arriba se deshizo. El libro, los papeles,
--     las reglas, los historiales, los contadores, las secuencias de la app
--     y las huellas están como al empezar.
do $$
declare
  v_antes text := current_setting('mx3.foto', true);
  v_ahora text;
begin
  v_ahora := pg_temp.c3_foto();
  insert into _pruebas values (91, 'no deja rastro: todo como al empezar', v_antes, v_ahora, v_ahora = v_antes);
end $$;

select * from _pruebas order by n;
