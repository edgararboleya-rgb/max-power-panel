-- =====================================================================
-- c18-pruebas.sql — la contabilidad en inglés y su mapeo fiscal se prueban
-- a sí mismos (c18-fiscal.sql). 21-nov-2026.
--
-- Se pega en el SQL Editor DESPUÉS de c18-fiscal.sql (o, en el banco:
--   PGPASSWORD=editor_sql psql -h 127.0.0.1 -p 5433 -U editor_sql -d <bd> -1 \
--     -f docs/conta/c18-pruebas.sql).
-- NO DEJA NADA: cada prueba corre en una subtransacción que se deshace
-- (MXT00); queda solo pruebas.c18_resultado con la última corrida. Valen
-- igual con la forma en «1120» o en «1120-S», confirmada o no (lo que haya
-- en la base no se toca: cada prueba pone la suya y se deshace).
--
--  1 el pegado: nada falta, las tablas con RLS, la vista, cada función con
--    su comentario, la configuración (una fila) y la marca;
--  2 los permisos: anon y service_role nada; quien no es el dueño, nada; las
--    tablas no se escriben a mano; el pegado no está en la API;
--  3 el catálogo: las tres formas; cada línea del mapeo existe en la suya;
--  4 los nombres y las categorías estándar de un contratista, y el español
--    de siempre sin tocar;
--  5 las líneas que importan en las DOS formas: los ingresos, el costo de
--    ventas con su 1125-A, los oficiales, las comidas, los intereses, las
--    donaciones, las multas, las distribuciones, el capital;
--  6 UN ajuste: la forma se cambia y todo lo sigue; cambiarla quita la
--    confirmación; confirmarla deja quién y cuándo; otra forma no existe;
--    solo el dueño;
--  7 una cuenta nueva sin fila sale con lo de su tipo y el control lo avisa;
--    con su línea puesta a mano queda fijada; una línea inventada, no;
--  8 EL PAQUETE: en inglés, con lo del año por su línea en el 1120 y en el
--    1120-S y el 1125-A; la balanza cuadra; avisa del tipo de entidad
--    mientras no esté confirmado, y deja de avisar al confirmarlo;
--  9 lo que lee la pantalla: la configuración, las secciones y todas las
--    cuentas; y leer no escribe nada;
-- 10 nada queda.
-- =====================================================================
create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

create temp table if not exists _f18 (k text primary key, v text);
truncate _f18;
insert into _f18 select 'dueno', id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
insert into _f18 select 'otro', (select id::text from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1);
insert into _f18 values ('d', greatest(fn_fecha_miami(now()) - 3, date_trunc('month', fn_fecha_miami(now()))::date)::text);
grant select on _f18 to public;

do $$
begin
  perform set_config('c4.control_tope', '0', false);
  perform set_config('mxp.cierre_sin_push', '1', false);
end $$;

create or replace function pg_temp.f18(k text) returns text language sql as $$ select v from _f18 where k = $1 $$;
create or replace function pg_temp.f18_ser(quien text) returns void language plpgsql as $$
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
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.f18(quien), 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', coalesce(pg_temp.f18(quien), ''), true);
    execute 'set local role authenticated';
  end if;
end $$;
-- lo que suma una línea del resumen de un paquete (0 si no está)
create or replace function pg_temp.f18_linea(p jsonb, p_que text, p_linea text) returns numeric language sql as $$
  select coalesce((select (x->>'amount')::numeric from jsonb_array_elements(p->p_que) x where x->>'line' = p_linea), 0)
$$;
create or replace function pg_temp.f18_conteos() returns text language sql as $$
  select format('config %s · lineas %s · cuentas %s · asientos %s · plan %s',
                (select md5(to_jsonb(g)::text) from fiscal_config g where g.id = 1), (select count(*) from fiscal_lineas),
                (select md5(string_agg(to_jsonb(f)::text, '|' order by f.codigo)) from fiscal_cuentas f), (select count(*) from asientos),
                (select md5(string_agg(k.codigo || k.nombre || coalesce(k.nombre_en, ''), '|' order by k.codigo)) from cuentas k))
$$;
insert into _f18 values ('antes', pg_temp.f18_conteos());

-- 1. El pegado.
do $$
declare
  v_obt text;
  v_esp text := 'nada falta | 3 tablas con RLS | 1 vista | funciones sin comentario c18: ninguna | ninguna SECURITY DEFINER | configuración: 1 fila | marca 2026112101';
begin
  begin
    perform pg_temp.f18_ser('editor');
    v_obt := format('%s | %s tablas con RLS | %s vista | funciones sin comentario c18: %s | %s | configuración: %s fila | marca %s',
      coalesce(fn_fiscal_precondiciones(), 'nada falta'),
      (select count(*) from pg_class k where k.relnamespace = 'public'::regnamespace and k.relkind = 'r' and k.relrowsecurity
          and k.relname in ('fiscal_config', 'fiscal_lineas', 'fiscal_cuentas')),
      (select count(*) from pg_views where schemaname = 'public' and viewname = 'v_fiscal_cuentas'),
      (select coalesce(string_agg(p.proname, ', '), 'ninguna') from pg_proc p
        where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_fiscal\_%' and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c18: %'),
      case when exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_fiscal\_%' and p.prosecdef)
           then 'HAY SECURITY DEFINER' else 'ninguna SECURITY DEFINER' end,
      (select count(*) from fiscal_config), fn_fiscal_version());
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (1, 'el pegado: nada falta, las tres tablas con RLS, la vista de las cuentas, cada función con su comentario «c18: …», ninguna SECURITY DEFINER, la configuración (una fila) y la marca de la versión',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 2. Los permisos.
do $$
declare
  v_obt text; a text; b text; c text; d text; e text;
  v_esp text := 'anon y service_role: nada | quien no es el dueño: nada | a mano, ni el dueño (MX003) | no se borra (MX003) | el pegado, fuera de la API';
begin
  begin
    select case when count(*) = 0 then 'nada' else 'EJECUTAN ' || string_agg(p.proname, ', ') end into a
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\_fiscal\_%'
       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('service_role', p.oid, 'execute'));
    if pg_temp.f18('otro') is null then
      b := 'nada';
    else
      perform pg_temp.f18_ser('otro');
      begin
        perform fn_fiscal_leer();
        b := 'LEE';
      exception when insufficient_privilege then
        b := case when (select count(*) from fiscal_cuentas) = 0 and (select count(*) from fiscal_config) = 0 then 'nada' else 'VE las tablas' end;
      end;
    end if;
    perform pg_temp.f18_ser('dueno');
    begin
      update fiscal_config set forma = '1120-S' where id = 1;
      c := 'SE DEJA';
    exception when sqlstate 'MX003' then c := 'MX003';
    end;
    perform pg_temp.f18_ser('editor');
    begin
      delete from fiscal_cuentas where codigo = '5100';
      d := 'SE DEJA';
    exception when sqlstate 'MX003' then d := 'MX003';
    end;
    select case when count(*) = 0 then 'fuera de la API' else 'EN LA API' end into e
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('fn_fiscal_pegado', 'fn_fiscal_precondiciones', 'fn_fiscal_guarda')
       and has_function_privilege('authenticated', p.oid, 'execute');
    v_obt := format('anon y service_role: %s | quien no es el dueño: %s | a mano, ni el dueño (%s) | no se borra (%s) | el pegado, %s', a, b, c, d, e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.f18_ser('editor');
  insert into _pruebas values (2, 'los permisos: anon y service_role no ejecutan nada; quien no es el dueño no lee nada; las tablas no se escriben a mano ni siendo el dueño, ni se borran; el pegado y las precondiciones no están en la API',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 3. El catálogo de líneas.
do $$
declare
  v_obt text;
  v_esp text := 'formas: 1120, 1120-S, 1125-A | líneas del mapeo que no existen: ninguna | 1120 línea 26 y 1120-S línea 20: Other deductions | Schedule L en las dos';
begin
  begin
    perform pg_temp.f18_ser('editor');
    v_obt := format('formas: %s | líneas del mapeo que no existen: %s | 1120 línea 26 y 1120-S línea 20: %s | Schedule L en las dos',
      (select string_agg(distinct l.forma, ', ' order by l.forma) from fiscal_lineas l),
      (select coalesce(string_agg(x.q, ', '), 'ninguna')
         from (select f.codigo || ':1120:' || f.linea_1120 as q from fiscal_cuentas f
                where f.linea_1120 is not null and not exists (select 1 from fiscal_lineas l where l.forma = '1120' and l.linea = f.linea_1120)
               union all
               select f.codigo || ':1120-S:' || f.linea_1120s from fiscal_cuentas f
                where f.linea_1120s is not null and not exists (select 1 from fiscal_lineas l where l.forma = '1120-S' and l.linea = f.linea_1120s)
               union all
               select f.codigo || ':1125-A:' || f.linea_1125a from fiscal_cuentas f
                where f.linea_1125a is not null and not exists (select 1 from fiscal_lineas l where l.forma = '1125-A' and l.linea = f.linea_1125a)) x),
      case when (select l.etiqueta_en from fiscal_lineas l where l.forma = '1120' and l.linea = '26') ~ 'Other deductions'
                and (select l.etiqueta_en from fiscal_lineas l where l.forma = '1120-S' and l.linea = '20') ~ 'Other deductions' then 'Other deductions'
           else 'NO' end);
    if (select count(*) from fiscal_lineas l where l.linea = 'L1') <> 2 then
      v_obt := v_obt || ' (FALTA Schedule L)';
    end if;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (3, 'el catálogo de líneas: las tres formas (1120, 1120-S y 1125-A); cada línea que usa una cuenta existe en el catálogo de su forma; «Other deductions» es la 26 del 1120 y la 20 del 1120-S; y el Schedule L está en las dos',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 4. Los nombres y las categorías estándar; el español, sin tocar.
do $$
declare
  v_obt text;
  v_esp text := 'Assets, Cost of Goods Sold (Job Costs), Equity, Income, Liabilities, Operating Expenses, Other Expense, Other Income | '
                '5100 Job Materials · 5200 Subcontractors · 6300 Vehicle Expense · 6005 Officer Compensation · 3200 Shareholder Distributions · 4010 Contract Revenue — Residential | '
                'el español del plan: igual que antes';
begin
  begin
    perform pg_temp.f18_ser('editor');
    v_obt := format('%s | %s | el español del plan: %s',
      (select string_agg(distinct v.seccion_en, ', ' order by v.seccion_en) from v_fiscal_cuentas v),
      (select string_agg(v.codigo || ' ' || v.nombre_en, ' · ' order by array_position(array['5100', '5200', '6300', '6005', '3200', '4010'], v.codigo))
         from v_fiscal_cuentas v where v.codigo in ('5100', '5200', '6300', '6005', '3200', '4010')),
      case when (select bool_and(v.nombre = k.nombre) and count(*) = (select count(*) from cuentas) from v_fiscal_cuentas v join cuentas k on k.codigo = v.codigo)
                and (select k.nombre from cuentas k where k.codigo = '5100') = 'Material' then 'igual que antes' else 'CAMBIÓ' end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  insert into _pruebas values (4, 'los nombres y las categorías estándar de un contratista en EE. UU.: las ocho categorías; el material es «Job Materials», los subcontratos «Subcontractors», lo personal «Shareholder Distributions»…; y el nombre en español de cada cuenta del plan es el de siempre (el inglés va al lado)',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 5. Las líneas que importan, en las dos formas.
do $$
declare
  v_obt text;
  v_esp text := '4010 1a/1a | 5000 2/2 (1125-A 3) | 5100 2/2 (1125-A 2) | 5200 2/2 (1125-A 5) | 6005 12/7 | 6000 13/8 | 6350 26/20 | 6700 22/16 | 6950 20/14 | '
                '7100 18/13 | 7910 19/K12a | 7920 M-1/K16c | 4910 5/K4 | 3200 M-2 5a/K16d | 3000 L22b/L22 | 3900 L25/L24 | 1010 L1/L1 | 2010 L16/L16 | '
                'todo el costo va a la línea 2 con su 1125-A';
begin
  begin
    perform pg_temp.f18_ser('editor');
    select string_agg(v.codigo || ' ' || v.linea_1120 || '/' || v.linea_1120s || coalesce(' (1125-A ' || v.linea_1125a || ')', ''), ' | '
                      order by array_position(array['4010', '5000', '5100', '5200', '6005', '6000', '6350', '6700', '6950', '7100', '7910', '7920', '4910',
                                                    '3200', '3000', '3900', '1010', '2010'], v.codigo))
      into v_obt
      from v_fiscal_cuentas v
     where v.codigo in ('4010', '5000', '5100', '5200', '6005', '6000', '6350', '6700', '6950', '7100', '7910', '7920', '4910', '3200', '3000', '3900', '1010', '2010')
       and not v.fijada;
    v_obt := v_obt || ' | ' || case when not exists (select 1 from v_fiscal_cuentas v where v.tipo = 'costo' and v.imputable and not v.fijada
                                                        and (v.linea_1120 <> '2' or v.linea_1120s <> '2' or v.linea_1125a is null))
                                    then 'todo el costo va a la línea 2 con su 1125-A' else 'HAY costo fuera de la línea 2' end;
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  if exists (select 1 from fiscal_cuentas f where f.fijada and f.codigo in ('4010', '5000', '5100', '5200', '6005', '6000', '6350', '6700', '6950', '7100', '7910',
                                                                             '7920', '4910', '3200', '3000', '3900', '1010', '2010')) then
    insert into _pruebas values (5, 'las líneas que importan en las dos formas', v_esp,
      'omitida: alguna de esas cuentas tiene su línea cambiada a mano (fijada): manda lo que puso el CPA', null);
  else
    insert into _pruebas values (5, 'las líneas que importan en las DOS formas (1120 / 1120-S): los ingresos, el costo de ventas con su línea del 1125-A (la mano de obra, las compras, lo demás), los oficiales, los sueldos, las comidas, la publicidad, la depreciación, los intereses, las donaciones, las multas (no deducibles), los intereses ganados, las distribuciones, el capital y el Schedule L',
      v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 6. UN ajuste: la forma.
do $$
declare
  v_obt text; r jsonb; a text; b text; c text; d text; e text; f text;
  v_esp text := 'a 1120-S: los oficiales pasan a la 7 y las donaciones a K12a | cambiarla quita la confirmación | confirmada: con quién y cuándo | '
                'otra forma: 22023 | otro: 42501 | de vuelta a 1120: los oficiales, a la 12';
begin
  begin
    perform pg_temp.f18_ser('dueno');
    perform fn_fiscal_forma('{"forma": "1120", "confirmada": true}');
    r := fn_fiscal_forma('{"forma": "1120-S"}');
    a := case when fn_fiscal_leer()->'cuentas'->'6005'->>'linea' = '7' and fn_fiscal_leer()->'cuentas'->'7910'->>'linea' = 'K12a'
                   and fn_fiscal_leer()->'config'->>'forma' = '1120-S' then 'los oficiales pasan a la 7 y las donaciones a K12a'
              else 'NO: ' || (fn_fiscal_leer()->'cuentas'->'6005')::text end;
    b := case when not (r->>'confirmada')::boolean then 'cambiarla quita la confirmación' else 'SIGUE confirmada' end;
    r := fn_fiscal_forma('{"confirmada": true, "nota": "c18-pruebas: lo confirmó el CPA"}');
    c := case when (r->>'confirmada')::boolean and (select g.confirmada_por = pg_temp.f18('dueno')::uuid and g.confirmada_el is not null from fiscal_config g where g.id = 1)
              then 'con quién y cuándo' else 'SIN quién o cuándo' end;
    begin
      perform fn_fiscal_forma('{"forma": "1065"}');
      d := 'LA ACEPTA';
    exception when sqlstate '22023' then d := '22023';
    end;
    if pg_temp.f18('otro') is null then
      e := '42501';
    else
      perform pg_temp.f18_ser('otro');
      begin
        perform fn_fiscal_forma('{"forma": "1120"}');
        e := 'LO DEJA';
      exception when insufficient_privilege then e := '42501';
      end;
    end if;
    perform pg_temp.f18_ser('dueno');
    perform fn_fiscal_forma('{"forma": "1120"}');
    f := case when fn_fiscal_leer()->'cuentas'->'6005'->>'linea' = '12' then 'los oficiales, a la 12' else 'NO' end;
    perform pg_temp.f18_ser('editor');
    v_obt := format('a 1120-S: %s | %s | confirmada: %s | otra forma: %s | otro: %s | de vuelta a 1120: %s', a, b, c, d, e, f);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.f18_ser('editor');
  if exists (select 1 from fiscal_cuentas f where f.fijada and f.codigo in ('6005', '7910')) then
    insert into _pruebas values (6, 'UN ajuste: la forma', v_esp, 'omitida: la 6005 o la 7910 tienen su línea cambiada a mano (fijada)', null);
  else
    insert into _pruebas values (6, 'UN ajuste: la forma se cambia con fn_fiscal_forma y todo lo sigue (la línea de cada cuenta es la de esa forma); cambiarla quita la confirmación; confirmarla deja escrito quién y cuándo; una forma que no es 1120 ni 1120-S no existe; y solo el dueño la cambia',
      v_esp, v_obt, v_obt = v_esp);
  end if;
end $$;

-- 7. Una cuenta nueva, y el mapeo a mano.
do $$
declare
  v_obt text; r jsonb; a text; b text; c text; d text;
  v_esp text := 'la cuenta nueva: Operating Expenses, 26/20, sin mapear | el control lo avisa | puesta a mano: 22/16, fijada, y deja de avisar | una línea inventada: 22023';
begin
  begin
    perform pg_temp.f18_ser('editor');
    insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
    values ('6995', 'c18-pruebas: cuenta nueva', 'c18 test: new account', 'gasto', 'debe', true, 'prohibida', 'prohibida');
    select format('%s, %s/%s, %s', v.seccion_en, v.linea_1120, v.linea_1120s, case when v.mapeada then 'MAPEADA' else 'sin mapear' end) into a
      from v_fiscal_cuentas v where v.codigo = '6995';
    b := case when exists (select 1 from fn_fiscal_control() k where k.orden = 40 and not k.ok and k.detalle ~ '6995') then 'el control lo avisa' else 'el control NO avisa' end;
    perform pg_temp.f18_ser('dueno');
    r := fn_fiscal_cuenta('{"codigo": "6995", "nombre_en": "Trade Show Advertising", "linea_1120": "22", "linea_1120s": "16"}');
    c := format('%s/%s, %s, y %s', r->>'linea_1120', r->>'linea_1120s', case when (r->>'fijada')::boolean then 'fijada' else 'SIN fijar' end,
                case when not exists (select 1 from fn_fiscal_control() k where k.orden = 40 and k.detalle ~ '6995') then 'deja de avisar' else 'SIGUE avisando' end);
    begin
      perform fn_fiscal_cuenta('{"codigo": "6995", "linea_1120": "99"}');
      d := 'LA ACEPTA';
    exception when sqlstate '22023' then d := '22023';
    end;
    perform pg_temp.f18_ser('editor');
    v_obt := format('la cuenta nueva: %s | %s | puesta a mano: %s | una línea inventada: %s', a, b, c, d);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.f18_ser('editor');
  insert into _pruebas values (7, 'una cuenta nueva del plan que todavía no tiene su fila sale con la categoría y la línea de su tipo, sin mapear, y el control lo avisa; al ponerle su línea a mano (fn_fiscal_cuenta) queda fijada y deja de avisar; y una línea que no está en el catálogo no se acepta',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 8. EL PAQUETE.
do $$
declare
  v_obt text; p0 jsonb; p1 jsonb; s0 jsonb; s1 jsonb; a text; b text; c text; d text; e text; f text; g text;
  v_anio int := extract(year from pg_temp.f18('d')::date)::int;
  v_esp text := 'en inglés (título, categorías, cuentas) | 1120: otros ingresos +500.00 a la 10, la gasolina +100.00 a la 26, la multa +25.00 a M-1, lo personal +40.00 a M-2 5a | '
                '1120-S: +500.00 a la 5, +100.00 a la 20, +25.00 a K16c, +40.00 a K16d | 1125-A: el material en bodega +200.00 a la 7 | la balanza cuadra | '
                'sin confirmar: avisa del tipo de entidad | confirmada: ya no avisa';
begin
  if exists (select 1 from fiscal_cuentas f where f.fijada and f.codigo in ('4900', '6300', '7920', '3200', '1300')) then
    insert into _pruebas values (8, 'EL PAQUETE', v_esp, 'omitida: alguna de las cuentas de la prueba tiene su línea cambiada a mano (fijada)', null);
    return;
  end if;
  begin
    perform pg_temp.f18_ser('dueno');
    perform fn_fiscal_forma('{"forma": "1120", "confirmada": false}');
    p0 := fn_fiscal_paquete(v_anio);
    s0 := fn_fiscal_paquete(v_anio, '1120-S');
    perform pg_temp.f18_ser('editor');
    perform fn_postear(jsonb_build_object('fecha', pg_temp.f18('d'), 'descripcion', 'c18-pruebas: movimientos de prueba (se deshace)',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', '1010', 'monto', '135.00'),
        jsonb_build_object('cuenta', '4900', 'monto', '-500.00'),
        jsonb_build_object('cuenta', '6300', 'monto', '100.00'),
        jsonb_build_object('cuenta', '7920', 'monto', '25.00'),
        jsonb_build_object('cuenta', '3200', 'monto', '40.00'),
        jsonb_build_object('cuenta', '1300', 'monto', '200.00'))));
    -- (el material en bodega, 1300, es la línea 7 del 1125-A —el inventario al cierre—; el material de una obra, 5100, pide su
    --  obra y aquí no se siembra ninguna: que va a la línea 2 lo mira la prueba 5)
    perform pg_temp.f18_ser('dueno');
    p1 := fn_fiscal_paquete(v_anio);
    s1 := fn_fiscal_paquete(v_anio, '1120-S');
    a := case when p1->>'title' ~ '^Year-End Accounting Package' and p1->'trial_balance' @> '[{"account": "6300", "name": "Vehicle Expense", "category": "Operating Expenses"}]'
                   and exists (select 1 from jsonb_array_elements(p1->'income_statement') x where x->>'label' = 'Operating Expenses')
              then 'en inglés (título, categorías, cuentas)' else 'NO está en inglés' end;
    b := format('1120: otros ingresos +%s a la 10, la gasolina +%s a la 26, la multa +%s a M-1, lo personal +%s a M-2 5a',
                pg_temp.f18_linea(p1, 'tax_lines', '10') - pg_temp.f18_linea(p0, 'tax_lines', '10'),
                pg_temp.f18_linea(p1, 'tax_lines', '26') - pg_temp.f18_linea(p0, 'tax_lines', '26'),
                pg_temp.f18_linea(p1, 'tax_lines', 'M-1') - pg_temp.f18_linea(p0, 'tax_lines', 'M-1'),
                pg_temp.f18_linea(p1, 'tax_lines', 'M-2 5a') - pg_temp.f18_linea(p0, 'tax_lines', 'M-2 5a'));
    c := format('1120-S: +%s a la 5, +%s a la 20, +%s a K16c, +%s a K16d',
                pg_temp.f18_linea(s1, 'tax_lines', '5') - pg_temp.f18_linea(s0, 'tax_lines', '5'),
                pg_temp.f18_linea(s1, 'tax_lines', '20') - pg_temp.f18_linea(s0, 'tax_lines', '20'),
                pg_temp.f18_linea(s1, 'tax_lines', 'K16c') - pg_temp.f18_linea(s0, 'tax_lines', 'K16c'),
                pg_temp.f18_linea(s1, 'tax_lines', 'K16d') - pg_temp.f18_linea(s0, 'tax_lines', 'K16d'));
    d := format('1125-A: el material en bodega +%s a la 7', pg_temp.f18_linea(p1, 'form_1125a', '7') - pg_temp.f18_linea(p0, 'form_1125a', '7'));
    e := case when (select sum((x->>'ending')::numeric) from jsonb_array_elements(p1->'trial_balance') x) = 0 then 'la balanza cuadra' else 'la balanza NO cuadra' end;
    f := case when p1->'warnings'->>0 ~ '^ENTITY TYPE PENDING CONFIRMATION' and not (p1->'entity'->>'confirmed')::boolean then 'avisa del tipo de entidad' else 'NO avisa' end;
    perform fn_fiscal_forma('{"confirmada": true}');
    g := case when not exists (select 1 from jsonb_array_elements_text(fn_fiscal_paquete(v_anio)->'warnings') w where w ~ 'PENDING CONFIRMATION')
                   and (fn_fiscal_paquete(v_anio)->'entity'->>'confirmed')::boolean then 'ya no avisa' else 'SIGUE avisando' end;
    perform pg_temp.f18_ser('editor');
    v_obt := format('%s | %s | %s | %s | %s | sin confirmar: %s | confirmada: %s', a, b, c, d, e, f, g);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.f18_ser('editor');
  insert into _pruebas values (8, 'EL PAQUETE de fin de año: en inglés; lo que se postea en el año aparece en su línea del Form 1120 y, pedido para el 1120-S, en la del 1120-S (otros ingresos, la gasolina, una multa no deducible, lo personal) y el material en bodega en el 1125-A; la balanza cuadra; avisa arriba del tipo de entidad mientras no esté confirmado, y deja de avisar al confirmarlo',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 9. Lo que lee la pantalla.
do $$
declare
  v_obt text; r jsonb; v_c0 text;
  v_esp text := 'la configuración, las secciones y todas las cuentas | Income, Cost of Goods Sold (Job Costs), Operating Expenses | no escribe nada';
begin
  begin
    v_c0 := pg_temp.f18_conteos();
    perform pg_temp.f18_ser('dueno');
    r := fn_fiscal_leer();
    perform pg_temp.f18_ser('editor');
    v_obt := format('%s | %s, %s, %s | %s',
      case when r->'config' ? 'forma' and r->'config' ? 'confirmada' and (select count(*) from jsonb_object_keys(r->'cuentas')) = (select count(*) from cuentas)
           then 'la configuración, las secciones y todas las cuentas' else 'FALTA algo' end,
      r->'secciones'->>'ingresos', r->'secciones'->>'costo', r->'secciones'->>'gastos',
      case when pg_temp.f18_conteos() = v_c0 then 'no escribe nada' else 'ESCRIBIÓ' end);
  exception when others then v_obt := 'error ' || sqlstate || ': ' || sqlerrm;
  end;
  perform pg_temp.f18_ser('editor');
  insert into _pruebas values (9, 'lo que lee la pantalla (fn_fiscal_leer): la configuración (la forma, si está confirmada), las etiquetas en inglés de las secciones del estado de resultados y todas las cuentas del plan con su nombre en inglés; y leer no escribe nada',
    v_esp, v_obt, v_obt = v_esp);
end $$;

-- 10. Nada queda.
do $$
declare
  v_obt text;
begin
  perform pg_temp.f18_ser('editor');
  v_obt := case when pg_temp.f18_conteos() = pg_temp.f18('antes') then 'igual que antes' else 'CAMBIÓ: ' || pg_temp.f18_conteos() end;
  insert into _pruebas values (10, 'nada queda de las pruebas: la configuración, el catálogo, el mapeo, los asientos y el plan de cuentas están como antes',
    'igual que antes', v_obt, v_obt = 'igual que antes');
end $$;

reset c4.control_tope;
reset mxp.cierre_sin_push;

-- El resultado también queda en una tabla de verdad (como las demás capas):
--   select * from pruebas.c18_resultado order by n;
create schema if not exists pruebas;
revoke all on schema pruebas from public, anon, authenticated, service_role;
create unlogged table if not exists pruebas.c18_resultado
  (n int, prueba text, esperado text, obtenido text, ok boolean, corrida timestamptz not null default now());
revoke all on pruebas.c18_resultado from public, anon, authenticated, service_role;
truncate pruebas.c18_resultado;
insert into pruebas.c18_resultado (n, prueba, esperado, obtenido, ok)
select n, prueba, esperado, obtenido, ok from _pruebas;

select * from _pruebas order by n;
