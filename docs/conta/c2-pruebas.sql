-- =====================================================================
-- C2 · Las pruebas del libro — Max Power Electrical Solutions, Inc.
-- Supabase → SQL Editor. Se pega ENTERO, después de c1 y c2-libro.sql.
-- Lo que enseña al final es la tabla de resultados: una fila por ataque,
-- con lo esperado, lo obtenido y ok. Todo en true = el libro aguanta.
--
-- NO DEJA RASTRO. Cada ataque es un bloque «do» con una subtransacción
-- adentro: se suplanta al usuario (request.jwt.claims + set local role),
-- se ataca, y al final se lanza MXT00 para DESHACER todo lo escrito (los
-- asientos de prueba, los números, los cierres de período). El resultado
-- viaja en variables, que no se deshacen, y se apunta en _pruebas, que es
-- temporal y muere con la sesión. La última prueba comprueba que el libro
-- quedó igual que al empezar.
--
-- Rojo primero: con solo el bloque A de c2-libro.sql, estas pruebas
-- fallan porque los ataques ENTRAN («entró»), no porque falte una
-- función. Con el bloque B, todas en true.
--
-- Los datos que usan se buscan, no se inventan: el dueño (rol 'dueno',
-- activo), uno del equipo (activo, no dueño), una obra, un cost code, las
-- cuentas por sus reglas y el mes abierto más antiguo (con su mes
-- siguiente). Si algo falta, la prueba sale «omitida» (ok vacío), no
-- falla.
-- =====================================================================

create temp table if not exists _pruebas(n int, prueba text, esperado text, obtenido text, ok boolean);
truncate _pruebas;

-- ---------------------------------------------------------------------
-- Preparación: solo lee. Guarda lo que usan todas las pruebas en ajustes
-- de la sesión (mx_pruebas.*), que mueren con ella.
-- ---------------------------------------------------------------------
do $$
declare
  v_dueno     uuid;
  v_equipo    uuid;
  v_obra      text;
  v_cc        text;
  v_c5        text;
  v_banco     text;
  v_gasto     text;
  v_mes       text;
  v_desde     date;
  v_sig       text;
  v_sig_desde date;
  v_apertura  date;
  v_bueno     jsonb;
begin
  select id into v_dueno from perfiles
   where rol = 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_equipo from perfiles
   where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1;
  select id into v_obra from proyectos order by id limit 1;
  select codigo into v_cc from codigos_partida order by codigo limit 1;
  -- Las cuentas se eligen por sus reglas, no por número (si Edgar corrige
  -- el plan, las pruebas siguen valiendo); se prefiere la de siempre.
  select codigo into v_c5 from cuentas
   where tipo = 'costo' and regla_obra = 'obligatoria' and regla_cost_code = 'obligatoria' and activa and imputable
   order by (codigo = '5100') desc, codigo limit 1;
  select codigo into v_banco from cuentas
   where tipo = 'activo' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '1010') desc, codigo limit 1;
  select codigo into v_gasto from cuentas
   where tipo = 'gasto' and regla_obra = 'prohibida' and activa and imputable
   order by (codigo = '6100') desc, codigo limit 1;
  select periodo, desde into v_mes, v_desde from periodos
   where tipo = 'mes' and estado = 'abierto' order by desde limit 1;
  select periodo, desde into v_sig, v_sig_desde from periodos
   where tipo = 'mes' and estado = 'abierto' and desde = (v_desde + interval '1 month')::date;
  select desde into v_apertura from periodos where tipo = 'apertura' order by desde limit 1;

  -- Un asiento bueno de 100.00 fechado el día 5 del mes abierto más antiguo.
  if v_obra is not null and v_cc is not null and v_c5 is not null and v_banco is not null and v_mes is not null then
    v_bueno := jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'),
      'descripcion', 'c2-pruebas: asiento de prueba (se deshace)',
      'lineas', jsonb_build_array(
        jsonb_build_object('cuenta', v_c5, 'monto', '100.00', 'proyecto_id', v_obra, 'cost_code', v_cc),
        jsonb_build_object('cuenta', v_banco, 'monto', '-100.00')));
  end if;

  perform set_config('mx_pruebas.dueno',     coalesce(v_dueno::text, ''), false);
  perform set_config('mx_pruebas.equipo',    coalesce(v_equipo::text, ''), false);
  perform set_config('mx_pruebas.obra',      coalesce(v_obra, ''), false);
  perform set_config('mx_pruebas.cc',        coalesce(v_cc, ''), false);
  perform set_config('mx_pruebas.c5',        coalesce(v_c5, ''), false);
  perform set_config('mx_pruebas.banco',     coalesce(v_banco, ''), false);
  perform set_config('mx_pruebas.gasto',     coalesce(v_gasto, ''), false);
  perform set_config('mx_pruebas.mes',       coalesce(v_mes, ''), false);
  perform set_config('mx_pruebas.desde',     coalesce(v_desde::text, ''), false);
  perform set_config('mx_pruebas.sig',       coalesce(v_sig, ''), false);
  perform set_config('mx_pruebas.sig_desde', coalesce(v_sig_desde::text, ''), false);
  perform set_config('mx_pruebas.apertura',  coalesce(v_apertura::text, ''), false);
  perform set_config('mx_pruebas.bueno',     coalesce(v_bueno::text, ''), false);

  -- La foto del libro antes de las pruebas (la última prueba la compara).
  perform set_config('mx_pruebas.foto',
    (select format('asientos=%s lineas=%s contadores=%s periodos=%s cerrados=%s inactivas=%s',
                   (select count(*) from asientos), (select count(*) from asiento_lineas),
                   (select coalesce(sum(ultimo), 0) from contadores), (select count(*) from periodos),
                   (select count(*) from periodos where estado = 'cerrado'),
                   (select count(*) from cuentas where not activa))),
    false);
end $$;


-- =====================================================================
-- Los ataques de f02
-- =====================================================================

-- 1. Descuadre por un centavo (el dueño, por fn_postear) → MX001.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (1, 'descuadre por un centavo (dueño, fn_postear)', 'MX001', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{lineas,1,monto}', '"-99.99"'));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (1, 'descuadre por un centavo (dueño, fn_postear)', 'MX001', v_obt, v_obt like 'MX001 %');
end $$;

-- 2. Mes cerrado, desde fn_postear: el editor cierra el mes abierto más
--    antiguo y el dueño intenta postear en él → MX002.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (2, 'mes cerrado desde fn_postear (dueño)', 'MX002', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_mes;
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (2, 'mes cerrado desde fn_postear (dueño)', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 3. Mes cerrado, desde el SQL Editor: insert directo en las tablas, sin
--    pasar por fn_postear (las columnas de sistema van con valores de
--    relleno: el trigger las pisa) → MX002.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (3, 'mes cerrado desde el SQL Editor (insert directo)', 'MX002', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_mes;
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, 100.00, v_obra, v_cc), (v_id, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          hash_anterior, hash)
    values (v_id, v_anio || '-999999', v_anio, 999999, 999999999, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: insert directo en mes cerrado', repeat('0', 64), repeat('f', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (3, 'mes cerrado desde el SQL Editor (insert directo)', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 4. Update a una línea ya asentada, desde el SQL Editor → MX003.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (4, 'update a una línea (SQL Editor)', 'MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    update asiento_lineas set monto = monto + 1 where asiento_id = v_id and orden = 1;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (4, 'update a una línea (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 5. Update a la cabecera: mover la fecha de un asiento a un mes cerrado,
--    desde el SQL Editor → MX003.
do $$
declare
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes       text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde     date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_obt       text;
begin
  if v_bueno is null or v_sig_desde is null then
    insert into _pruebas values (5, 'update a la cabecera: fecha a un mes cerrado (SQL Editor)', 'MX003', 'omitida: faltan dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    -- el asiento va en el mes siguiente; luego se cierra el mes anterior y
    -- se intenta llevar la fecha allí.
    v_id := (fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_sig_desde + 4, 'YYYY-MM-DD'))))->>'id')::uuid;
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_mes;
    update asientos set fecha_contable = v_desde + 4, periodo = v_mes where id = v_id;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (5, 'update a la cabecera: fecha a un mes cerrado (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 6. Delete de las líneas y delete de la cabecera, desde el SQL Editor →
--    MX003 los dos.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_lin   text;
  v_cab   text;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (6, 'delete de líneas y de cabecera (SQL Editor)', 'lineas=MX003 cabecera=MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    begin
      delete from asiento_lineas where asiento_id = v_id;
      v_lin := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_lin := sqlstate;
    end;
    begin
      delete from asientos where id = v_id;
      v_cab := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_cab := sqlstate;
    end;
    v_obt := format('lineas=%s cabecera=%s', v_lin, v_cab);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (6, 'delete de líneas y de cabecera (SQL Editor)', 'lineas=MX003 cabecera=MX003', v_obt,
                               v_obt = 'lineas=MX003 cabecera=MX003');
end $$;

-- 7. Truncate del libro, desde el SQL Editor → MX003.
do $$
declare
  v_obt text;
begin
  begin
    truncate asientos, asiento_lineas;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (7, 'truncate del libro (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 8. La fecha de frontera: 31-dic a las 7 pm de Miami, con la sesión en
--    UTC (donde ya es 1-ene). fn_fecha_miami tiene que decir 2026-12-31.
do $$
declare
  v_obt text;
begin
  begin
    execute 'set local timezone = ''UTC''';
    v_obt := fn_fecha_miami('2026-12-31 19:00-05'::timestamptz)::text;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (8, 'fecha 31-dic 19:00 Miami con la sesión en UTC', '2026-12-31', v_obt, v_obt = '2026-12-31');
end $$;

-- 9. Un trabajador con su login lee CERO filas del libro (aunque haya).
do $$
declare
  v_equipo uuid  := nullif(current_setting('mx_pruebas.equipo', true), '')::uuid;
  v_bueno  jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt    text;
begin
  if v_equipo is null or v_bueno is null then
    insert into _pruebas values (9, 'el equipo lee 0 filas del libro', 'asientos=0 lineas=0 cuentas=0 periodos=0 contadores=0', 'omitida: no hay perfil de equipo o falta el asiento de prueba', null);
    return;
  end if;
  begin
    perform fn_postear(v_bueno);  -- como editor: que haya al menos un asiento
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select format('asientos=%s lineas=%s cuentas=%s periodos=%s contadores=%s',
                  (select count(*) from asientos), (select count(*) from asiento_lineas),
                  (select count(*) from cuentas), (select count(*) from periodos),
                  (select count(*) from contadores))
      into v_obt;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (9, 'el equipo lee 0 filas del libro', 'asientos=0 lineas=0 cuentas=0 periodos=0 contadores=0',
                               v_obt, v_obt = 'asientos=0 lineas=0 cuentas=0 periodos=0 contadores=0');
end $$;

-- 10. Un trabajador no puede postear (fn_postear) → 42501.
do $$
declare
  v_equipo uuid  := nullif(current_setting('mx_pruebas.equipo', true), '')::uuid;
  v_bueno  jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt    text;
begin
  if v_equipo is null or v_bueno is null then
    insert into _pruebas values (10, 'el equipo no puede postear', '42501', 'omitida: no hay perfil de equipo o falta el asiento de prueba', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (10, 'el equipo no puede postear', '42501', v_obt, v_obt like '42501 %');
end $$;

-- 11. anon (sin sesión) no puede nada: ni leer el libro ni el plan, ni
--     postear, ni pedir el estado.
do $$
declare
  v_bueno jsonb := coalesce(nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb, '{}'::jsonb);
  v_mes   text  := coalesce(nullif(current_setting('mx_pruebas.mes', true), ''), '2026-10');
  v_a     text;
  v_c     text;
  v_p     text;
  v_e     text;
  v_obt   text;
begin
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    execute 'set local role anon';
    begin
      select count(*) || ' filas' into v_a from asientos;
    exception when others then v_a := sqlstate;
    end;
    begin
      select count(*) || ' filas' into v_c from cuentas;
    exception when others then v_c := sqlstate;
    end;
    begin
      perform fn_postear(v_bueno);
      v_p := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_p := sqlstate;
    end;
    begin
      perform * from fn_estado(v_mes);
      v_e := 'entró';
    exception when others then v_e := sqlstate;
    end;
    v_obt := format('asientos=%s cuentas=%s postear=%s estado=%s', v_a, v_c, v_p, v_e);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (11, 'anon no puede nada', 'asientos=42501 cuentas=42501 postear=42501 estado=42501', v_obt,
                               v_obt = 'asientos=42501 cuentas=42501 postear=42501 estado=42501');
end $$;

-- 12. Reversar dos veces el mismo asiento (el dueño) → el segundo MX007.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (12, 'reversar dos veces (dueño)', 'MX007', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    perform fn_reversar(v_id, 'c2-pruebas: primer reverso');
    perform fn_reversar(v_id, 'c2-pruebas: segundo reverso');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (12, 'reversar dos veces (dueño)', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 13. Reversar un reverso (el dueño) → MX007.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_rev   uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (13, 'reversar un reverso (dueño)', 'MX007', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id  := (fn_postear(v_bueno)->>'id')::uuid;
    v_rev := (fn_reversar(v_id, 'c2-pruebas: reverso')->>'id')::uuid;
    perform fn_reversar(v_rev, 'c2-pruebas: reverso del reverso');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (13, 'reversar un reverso (dueño)', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 14. El reverso de un asiento de un período YA CERRADO cae el día 1 del
--     mes abierto siguiente, no en el cerrado.
do $$
declare
  v_dueno     uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes       text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_sig       text  := nullif(current_setting('mx_pruebas.sig', true), '');
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_r         jsonb;
  v_esp       text;
  v_obt       text;
begin
  v_esp := format('fecha=%s periodo=%s', v_sig_desde, v_sig);
  if v_dueno is null or v_bueno is null or v_sig is null then
    insert into _pruebas values (14, 'reverso de un asiento en período cerrado cae en el abierto', v_esp, 'omitida: faltan dueño o dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;   -- como editor, en el mes abierto más antiguo
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_mes;
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_r := fn_reversar(v_id, 'c2-pruebas: error hallado con el mes ya cerrado');
    v_obt := format('fecha=%s periodo=%s', v_r->>'fecha_contable', v_r->>'periodo');
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (14, 'reverso de un asiento en período cerrado cae en el abierto', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 15. Bueno, descuadrado, bueno: el descuadrado no entra y los dos buenos
--     quedan con números seguidos (sin hueco).
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_n1    int;
  v_n2    int;
  v_des   text;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (15, 'bueno, descuadrado, bueno: números sin hueco', 'descuadrado=MX001 salto=1', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_n1 := split_part(fn_postear(v_bueno)->>'numero', '-', 2)::int;
    begin
      perform fn_postear(jsonb_set(v_bueno, '{lineas,1,monto}', '"-99.99"'));
      v_des := 'entró';
    exception when others then v_des := sqlstate;
    end;
    v_n2 := split_part(fn_postear(v_bueno)->>'numero', '-', 2)::int;
    v_obt := format('descuadrado=%s salto=%s', v_des, v_n2 - v_n1);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (15, 'bueno, descuadrado, bueno: números sin hueco', 'descuadrado=MX001 salto=1', v_obt,
                               v_obt = 'descuadrado=MX001 salto=1');
end $$;

-- 16. Un monto con tres decimales → MX005 (numeric(14,2) lo redondearía
--     callado; la base lo rechaza antes).
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (16, 'monto con tres decimales', 'MX005', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(jsonb_set(v_bueno, '{lineas,0,monto}', '"100.005"'), '{lineas,1,monto}', '"-100.005"'));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (16, 'monto con tres decimales', 'MX005', v_obt, v_obt like 'MX005 %');
end $$;

-- 17. Una cuenta inactiva no recibe asientos → MX004.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_gasto text  := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_obt   text;
begin
  if v_dueno is null or v_gasto is null or v_banco is null or v_desde is null then
    insert into _pruebas values (17, 'cuenta inactiva', 'MX004', 'omitida: falta dueño, cuenta o mes abierto', null);
    return;
  end if;
  begin
    update cuentas set activa = false where codigo = v_gasto;   -- el editor la inactiva
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: a una cuenta inactiva',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_gasto, 'monto', '50.00'),
                                  jsonb_build_object('cuenta', v_banco, 'monto', '-50.00'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (17, 'cuenta inactiva', 'MX004', v_obt, v_obt like 'MX004 %');
end $$;

-- 18. Costo (5xxx) sin obra → MX006.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (18, 'costo 5xxx sin obra', 'MX006', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(v_bueno #- '{lineas,0,proyecto_id}' #- '{lineas,0,cost_code}');
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (18, 'costo 5xxx sin obra', 'MX006', v_obt, v_obt like 'MX006 %');
end $$;

-- 19. Gasto general (6xxx) con obra → MX006 (el overhead nunca va por obra
--     en el libro).
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_gasto text := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_obt   text;
begin
  if v_dueno is null or v_gasto is null or v_banco is null or v_obra is null or v_desde is null then
    insert into _pruebas values (19, 'gasto 6xxx con obra', 'MX006', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: renta cargada a una obra',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_gasto, 'monto', '50.00', 'proyecto_id', v_obra),
                                  jsonb_build_object('cuenta', v_banco, 'monto', '-50.00'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (19, 'gasto 6xxx con obra', 'MX006', v_obt, v_obt like 'MX006 %');
end $$;

-- 20. Un asiento reversible genera, en la misma transacción, su reverso
--     automático fechado el día 1 del mes siguiente.
do $$
declare
  v_dueno     uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno     jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_sig_desde date  := nullif(current_setting('mx_pruebas.sig_desde', true), '')::date;
  v_id        uuid;
  v_esp       text;
  v_obt       text;
begin
  v_esp := format('reverso=%s camino=reverso_automatico', v_sig_desde);
  if v_dueno is null or v_bueno is null or v_sig_desde is null then
    insert into _pruebas values (20, 'reversible genera su reverso el día 1', v_esp, 'omitida: faltan dueño o dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno || '{"reversible": true}'::jsonb)->>'id')::uuid;
    select format('reverso=%s camino=%s', coalesce(max(r.fecha_contable)::text, '-'), coalesce(max(r.camino), '-'))
      into v_obt
      from asientos r
     where r.reversa_a = v_id;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (20, 'reversible genera su reverso el día 1', v_esp, v_obt, v_obt = v_esp);
end $$;

-- 21. La cadena, sana: después de postear, reversar y un reversible,
--     fn_verificar_cadena da sus nueve controles en true (el detector no
--     grita de más).
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (21, 'cadena íntegra tras posteos normales', 'controles=9 fallan=0', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    perform fn_reversar(v_id, 'c2-pruebas: reverso');
    perform fn_postear(v_bueno || '{"reversible": true}'::jsonb);
    select format('controles=%s fallan=%s', count(*), count(*) filter (where not v.ok))
      into v_obt
      from fn_verificar_cadena() v;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (21, 'cadena íntegra tras posteos normales', 'controles=9 fallan=0', v_obt, v_obt = 'controles=9 fallan=0');
end $$;

-- 22. Lo que no se puede impedir, se detecta: el SQL Editor apaga los
--     triggers de las líneas, mueve 10.00 de un lado a otro (el asiento
--     sigue cuadrado) y los vuelve a encender. Mientras están apagados,
--     fn_verificar_cadena lo dice (triggers); después, la cadena de
--     hashes delata el cambio (hash). Si el editor no tuviera permiso
--     para apagarlos (42501), la prueba lo apunta como bueno: tampoco hay
--     por dónde entrar. Cualquier otro error es un fallo.
do $$
declare
  v_bueno   jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id      uuid;
  v_apagado text;
  v_hash    text;
  v_obt     text;
  v_ok      boolean;
begin
  if v_bueno is null then
    insert into _pruebas values (22, 'la cadena detecta un cambio hecho con los triggers apagados', 'triggers=f hash=f', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    -- Un ALTER TABLE no corre con comprobaciones diferidas pendientes sobre
    -- la tabla (la FK diferida de las líneas recién puestas): se disparan
    -- ya. Se deshace con la subtransacción, como todo lo demás.
    set constraints all immediate;
    begin
      execute 'alter table public.asiento_lineas disable trigger user';
    exception when insufficient_privilege then
      v_obt := format('el editor no puede apagar los triggers (%s)', sqlstate);
    end;
    if v_obt is null then
      select coalesce(max(v.ok::text), '-') into v_apagado from fn_verificar_cadena() v where v.control = 'triggers';
      update asiento_lineas set monto = monto + 10 where asiento_id = v_id and monto > 0;
      update asiento_lineas set monto = monto - 10 where asiento_id = v_id and monto < 0;
      execute 'alter table public.asiento_lineas enable trigger user';
      select coalesce(max(v.ok::text), '-') into v_hash from fn_verificar_cadena() v where v.control = 'hash';
      v_obt := format('triggers=%s hash=%s',
                      case v_apagado when 'false' then 'f' when 'true' then 't' else v_apagado end,
                      case v_hash when 'false' then 'f' when 'true' then 't' else v_hash end);
    end if;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  v_ok := v_obt = 'triggers=f hash=f' or v_obt like 'el editor no puede apagar los triggers%';
  insert into _pruebas values (22, 'la cadena detecta un cambio hecho con los triggers apagados', 'triggers=f hash=f', v_obt, v_ok);
end $$;


-- =====================================================================
-- Más ataques: los que un auditor preguntaría después
-- =====================================================================

-- 23. service_role (las funciones de borde, la IA) no postea → 42501.
--     «La IA propone, nunca postea» lo garantiza la base.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (23, 'service_role no postea (la IA nunca postea)', '42501', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
    execute 'set local role service_role';
    perform fn_postear(v_bueno);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (23, 'service_role no postea (la IA nunca postea)', '42501', v_obt, v_obt like '42501 %');
end $$;

-- 24. Un período cerrado no se reabre, ni desde el SQL Editor → MX002.
do $$
declare
  v_mes text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_obt text;
begin
  if v_mes is null then
    insert into _pruebas values (24, 'reabrir un período cerrado (SQL Editor)', 'MX002', 'omitida: no hay mes abierto', null);
    return;
  end if;
  begin
    update periodos set estado = 'cerrado', cerrado_el = now() where periodo = v_mes;
    update periodos set estado = 'abierto', cerrado_el = null, cerrado_por = null, cerrado_rol = null,
                        cadena_al_cerrar = null
     where periodo = v_mes;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (24, 'reabrir un período cerrado (SQL Editor)', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 25. El contador no se salta números, ni desde el SQL Editor → MX003.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_n     int;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (25, 'saltar números en el contador (SQL Editor)', 'MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform fn_postear(v_bueno);
    update contadores set ultimo = ultimo + 5 where serie = 'asientos-' || extract(year from v_desde)::int;
    get diagnostics v_n = row_count;
    v_obt := case when v_n = 0 then 'no había contador que saltar' else 'entró' end;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (25, 'saltar números en el contador (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 26. Una línea nueva en un asiento ya sellado (SQL Editor) → MX003.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_gasto text  := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_id    uuid;
  v_obt   text;
begin
  if v_bueno is null or v_gasto is null then
    insert into _pruebas values (26, 'línea nueva en un asiento sellado (SQL Editor)', 'MX003', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    insert into asiento_lineas (asiento_id, orden, cuenta, monto) values (v_id, 3, v_gasto, 1.00);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (26, 'línea nueva en un asiento sellado (SQL Editor)', 'MX003', v_obt, v_obt like 'MX003 %');
end $$;

-- 27. Un asiento descuadrado insertado a mano en el SQL Editor, sin
--     fn_postear: el trigger de la cabecera lo para igual → MX001.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (27, 'asiento descuadrado insertado a mano (SQL Editor)', 'MX001', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, 100.00, v_obra, v_cc), (v_id, 2, v_banco, -99.99, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          hash_anterior, hash)
    values (v_id, v_anio || '-999998', v_anio, 999998, 999999998, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: descuadrado a mano', repeat('0', 64), repeat('e', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (27, 'asiento descuadrado insertado a mano (SQL Editor)', 'MX001', v_obt, v_obt like 'MX001 %');
end $$;

-- 28. Un «reverso» fabricado a mano que no es el espejo de su original
--     (SQL Editor) → MX007.
do $$
declare
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_obra  text  := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text  := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text  := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text  := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date  := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_orig  uuid;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_bueno is null then
    insert into _pruebas values (28, 'reverso fabricado que no es espejo (SQL Editor)', 'MX007', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    v_orig := (fn_postear(v_bueno)->>'id')::uuid;   -- el original es de 100.00
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, -50.00, v_obra, v_cc), (v_id, 2, v_banco, 50.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          motivo, reversa_a, hash_anterior, hash)
    values (v_id, v_anio || '-999997', v_anio, 999997, 999999997, v_desde + 4, v_mes, 'reverso',
            'c2-pruebas: medio reverso', 'c2-pruebas', v_orig, repeat('0', 64), repeat('d', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (28, 'reverso fabricado que no es espejo (SQL Editor)', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 29. Una cuenta con movimientos ni se borra ni cambia de código (SQL
--     Editor) → MX003 las dos. Es la guarda de c1.
do $$
declare
  v_gasto text := nullif(current_setting('mx_pruebas.gasto', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_bor   text;
  v_cod   text;
  v_obt   text;
begin
  if v_gasto is null or v_banco is null or v_desde is null then
    insert into _pruebas values (29, 'cuenta con movimientos: ni se borra ni cambia de código', 'borrar=MX003 codigo=MX003', 'omitida: falta cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform fn_postear(jsonb_build_object(
      'fecha', to_char(v_desde + 4, 'YYYY-MM-DD'), 'descripcion', 'c2-pruebas: un gasto',
      'lineas', jsonb_build_array(jsonb_build_object('cuenta', v_gasto, 'monto', '75.00'),
                                  jsonb_build_object('cuenta', v_banco, 'monto', '-75.00'))));
    begin
      delete from cuentas where codigo = v_gasto;
      v_bor := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_bor := sqlstate;
    end;
    begin
      update cuentas set codigo = '6999' where codigo = v_gasto;
      v_cod := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_cod := sqlstate;
    end;
    v_obt := format('borrar=%s codigo=%s', v_bor, v_cod);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (29, 'cuenta con movimientos: ni se borra ni cambia de código', 'borrar=MX003 codigo=MX003', v_obt,
                               v_obt = 'borrar=MX003 codigo=MX003');
end $$;

-- 30. fn_postear no acepta lo que no es suyo: una clave mal escrita
--     («reversibel») ni un camino dictado por el cliente → 22023 los dos.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mal   text;
  v_cam   text;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (30, 'clave mal escrita y camino dictado por el cliente', 'clave=22023 camino=22023', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    begin
      perform fn_postear(v_bueno || '{"reversibel": true}'::jsonb);
      v_mal := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_mal := sqlstate;
    end;
    begin
      perform fn_postear(v_bueno || '{"camino": "puente"}'::jsonb);
      v_cam := 'entró';
      raise exception using errcode = 'MXT01';
    exception
      when sqlstate 'MXT01' then null;
      when others then v_cam := sqlstate;
    end;
    v_obt := format('clave=%s camino=%s', v_mal, v_cam);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (30, 'clave mal escrita y camino dictado por el cliente', 'clave=22023 camino=22023', v_obt,
                               v_obt = 'clave=22023 camino=22023');
end $$;

-- 31. El sello lo pone la base: un asiento del dueño por la app queda con
--     camino mano, su usuario y el rol authenticated.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_id    uuid;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (31, 'el sello (camino, usuario, rol) lo pone la base', 'camino=mano usuario=dueño rol=authenticated', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    v_id := (fn_postear(v_bueno)->>'id')::uuid;
    select format('camino=%s usuario=%s rol=%s', a.camino,
                  case when a.usuario_id = v_dueno then 'dueño' else coalesce(a.usuario_id::text, 'nulo') end,
                  a.rol_bd)
      into v_obt
      from asientos a where a.id = v_id;
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (31, 'el sello (camino, usuario, rol) lo pone la base', 'camino=mano usuario=dueño rol=authenticated', v_obt,
                               v_obt = 'camino=mano usuario=dueño rol=authenticated');
end $$;

-- 32. fn_estado, la fila de control: un asiento de 100.00 suma dos filas
--     y 100.00 al debe, y el período sigue cuadrando.
do $$
declare
  v_dueno uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_mes   text  := nullif(current_setting('mx_pruebas.mes', true), '');
  v_f0    bigint;
  v_d0    numeric;
  v_f1    bigint;
  v_d1    numeric;
  v_c1    boolean;
  v_obt   text;
begin
  if v_dueno is null or v_bueno is null then
    insert into _pruebas values (32, 'fn_estado cuenta filas, suma el debe y cuadra', 'filas+2 debe+100.00 cuadra=t', 'omitida: falta dueño, obra, cuenta o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    select e.filas, e.total_debe into v_f0, v_d0 from fn_estado(v_mes) e;
    perform fn_postear(v_bueno);
    select e.filas, e.total_debe, e.cuadra into v_f1, v_d1, v_c1 from fn_estado(v_mes) e;
    v_obt := format('filas+%s debe+%s cuadra=%s', v_f1 - v_f0, v_d1 - v_d0, case when v_c1 then 't' else 'f' end);
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (32, 'fn_estado cuenta filas, suma el debe y cuadra', 'filas+2 debe+100.00 cuadra=t', v_obt,
                               v_obt = 'filas+2 debe+100.00 cuadra=t');
end $$;

-- 33. El período de apertura solo admite el asiento de apertura: un
--     asiento normal fechado ese día → MX002.
do $$
declare
  v_dueno    uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno    jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_apertura date  := nullif(current_setting('mx_pruebas.apertura', true), '')::date;
  v_obt      text;
begin
  if v_dueno is null or v_bueno is null or v_apertura is null then
    insert into _pruebas values (33, 'la apertura solo admite la apertura', 'MX002', 'omitida: falta dueño o el período de apertura', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_apertura, 'YYYY-MM-DD'))));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (33, 'la apertura solo admite la apertura', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 34. Un trabajador no cierra un período (fn_cerrar_periodo) → 42501.
do $$
declare
  v_equipo uuid := nullif(current_setting('mx_pruebas.equipo', true), '')::uuid;
  v_mes    text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_obt    text;
begin
  if v_equipo is null or v_mes is null then
    insert into _pruebas values (34, 'el equipo no cierra un período', '42501', 'omitida: no hay perfil de equipo o mes abierto', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_equipo, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo(v_mes);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (34, 'el equipo no cierra un período', '42501', v_obt, v_obt like '42501 %');
end $$;

-- 35. Los meses se cierran en orden: el dueño intenta cerrar el mes
--     siguiente con el anterior abierto → MX002.
do $$
declare
  v_dueno uuid := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_sig   text := nullif(current_setting('mx_pruebas.sig', true), '');
  v_obt   text;
begin
  if v_dueno is null or v_sig is null then
    insert into _pruebas values (35, 'cerrar un mes con el anterior abierto', 'MX002', 'omitida: faltan dueño o dos meses abiertos seguidos', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_cerrar_periodo(v_sig);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (35, 'cerrar un mes con el anterior abierto', 'MX002', v_obt, v_obt like 'MX002 %');
end $$;

-- 36. Un asiento reversible metido a mano SIN su reverso no llega al
--     commit (se adelanta la comprobación diferida con set constraints)
--     → MX007.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id    uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (36, 'reversible sin su reverso no llega al commit', 'MX007', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id, 1, v_c5, 100.00, v_obra, v_cc), (v_id, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          reversible, hash_anterior, hash)
    values (v_id, v_anio || '-999996', v_anio, 999996, 999999996, v_desde + 4, v_mes, 'mano',
            'c2-pruebas: devengo sin su reverso', true, repeat('0', 64), repeat('c', 64));
    set constraints all immediate;
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (36, 'reversible sin su reverso no llega al commit', 'MX007', v_obt, v_obt like 'MX007 %');
end $$;

-- 37. El asiento de apertura es balance únicamente: una línea a una
--     cuenta de resultados (5xxx) → MX006. Solo mientras la apertura siga
--     abierta (después, la base ya no deja escribir ahí: MX002).
do $$
declare
  v_dueno    uuid  := nullif(current_setting('mx_pruebas.dueno', true), '')::uuid;
  v_bueno    jsonb := nullif(current_setting('mx_pruebas.bueno', true), '')::jsonb;
  v_apertura date  := nullif(current_setting('mx_pruebas.apertura', true), '')::date;
  v_abierta  boolean;
  v_obt      text;
begin
  select p.estado = 'abierto' into v_abierta from periodos p where p.tipo = 'apertura' and p.desde = v_apertura;
  if v_dueno is null or v_bueno is null or not coalesce(v_abierta, false) then
    insert into _pruebas values (37, 'la apertura es balance únicamente', 'MX006', 'omitida: falta dueño o la apertura ya está cerrada', null);
    return;
  end if;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    perform fn_postear(jsonb_set(v_bueno, '{fecha}', to_jsonb(to_char(v_apertura, 'YYYY-MM-DD')))
                       || '{"tipo": "apertura"}'::jsonb);
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (37, 'la apertura es balance únicamente', 'MX006', v_obt, v_obt like 'MX006 %');
end $$;

-- 38. Un documento, un asiento: el mismo papel posteado dos veces por un
--     puente → el segundo da 23505 en asientos_origen_unico. Es la
--     idempotencia que usan los puentes de f03 (correr dos veces no
--     duplica). El puente se simula desde el SQL Editor.
do $$
declare
  v_obra  text := nullif(current_setting('mx_pruebas.obra', true), '');
  v_cc    text := nullif(current_setting('mx_pruebas.cc', true), '');
  v_c5    text := nullif(current_setting('mx_pruebas.c5', true), '');
  v_banco text := nullif(current_setting('mx_pruebas.banco', true), '');
  v_mes   text := nullif(current_setting('mx_pruebas.mes', true), '');
  v_desde date := nullif(current_setting('mx_pruebas.desde', true), '')::date;
  v_id1   uuid := gen_random_uuid();
  v_id2   uuid := gen_random_uuid();
  v_anio  int;
  v_obt   text;
begin
  if v_obra is null or v_cc is null or v_c5 is null or v_banco is null or v_mes is null then
    insert into _pruebas values (38, 'un documento, un asiento (el puente corre dos veces)', '23505', 'omitida: falta obra, cuenta o mes abierto', null);
    return;
  end if;
  v_anio := extract(year from v_desde)::int;
  begin
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id1, 1, v_c5, 100.00, v_obra, v_cc), (v_id1, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          origen_tabla, origen_id, hash_anterior, hash)
    values (v_id1, v_anio || '-999995', v_anio, 999995, 999999995, v_desde + 4, v_mes, 'puente',
            'c2-pruebas: recibo por puente', 'recibos', 'c2-pruebas-1', repeat('0', 64), repeat('b', 64));
    insert into asiento_lineas (asiento_id, orden, cuenta, monto, proyecto_id, cost_code)
    values (v_id2, 1, v_c5, 100.00, v_obra, v_cc), (v_id2, 2, v_banco, -100.00, null, null);
    insert into asientos (id, numero, anio, secuencia, cadena_pos, fecha_contable, periodo, camino, descripcion,
                          origen_tabla, origen_id, hash_anterior, hash)
    values (v_id2, v_anio || '-999994', v_anio, 999994, 999999994, v_desde + 4, v_mes, 'puente',
            'c2-pruebas: el mismo recibo otra vez', 'recibos', 'c2-pruebas-1', repeat('1', 64), repeat('a', 64));
    v_obt := 'entró';
    raise exception using errcode = 'MXT00';
  exception
    when sqlstate 'MXT00' then null;
    when others then v_obt := sqlstate || ' ' || left(sqlerrm, 70);
  end;
  insert into _pruebas values (38, 'un documento, un asiento (el puente corre dos veces)', '23505', v_obt, v_obt like '23505 %');
end $$;

-- 39. Las pruebas no dejaron rastro: el libro está igual que al empezar.
do $$
declare
  v_antes text := current_setting('mx_pruebas.foto', true);
  v_obt   text;
begin
  select format('asientos=%s lineas=%s contadores=%s periodos=%s cerrados=%s inactivas=%s',
                (select count(*) from asientos), (select count(*) from asiento_lineas),
                (select coalesce(sum(ultimo), 0) from contadores), (select count(*) from periodos),
                (select count(*) from periodos where estado = 'cerrado'),
                (select count(*) from cuentas where not activa))
    into v_obt;
  insert into _pruebas values (39, 'las pruebas no dejan rastro', v_antes, v_obt, v_obt = v_antes);
end $$;

select * from _pruebas order by n;
