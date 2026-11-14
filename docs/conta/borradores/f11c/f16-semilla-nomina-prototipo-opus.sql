-- ===== 10. (14-nov, Fase 11c) LA NÓMINA DE GUSTO (c15), DE VERDAD =====
-- (PROTOTIPO del agente de la pantalla para f16-semilla.sql: va ANTES de «lo sembrado, en una línea por cosa».)
-- Solo si c15 está en esta base (sobre g12a, sin c15, no siembra nada: el tablero dice que la nómina no está pegada).
-- Dos nóminas regulares de Gusto, cada dos semanas, de tres personas inventadas («ZZ Nomina Uno», «ZZ Nomina Dos» —de campo— y
-- «ZZ Oficial Tres» —el accionista-oficial—), por el camino de c15 (el journal importado, la gente enlazada, la propuesta vista
-- y posteada), con sus horas aprobadas en dos obras de la semilla:
--   A · período de hoy−28 a hoy−15, día de pago hoy−11: posteada; sus cargos de Gusto en el banco (Plaid), dos días antes del día
--       de pago (y nunca antes del día 1 del mes de hoy: los meses de antes ya están conciliados): el NETO (5,171.63) y los
--       IMPUESTOS (1,522.54) casados desde Nómina → Cargos de Gusto; el REEMPLEO de Florida (166.51) y la MANUTENCIÓN (40.00)
--       esperan en la Bandeja;
--   B · período de hoy−14 a hoy−1, día de pago hoy+3: posteada (Gusto ya la corrió: su journal ya está) y SIN cargos todavía
--       (Gusto cobra dos días antes del día de pago): la proyección de la caja la resta en su día.
-- La bolsa del burden real (5015) queda sin repartir (lo del patrón de las dos).
-- Nada de esto es de nadie: nombres «ZZ…», montos inventados que cuadran al centavo.
\set n_uno  '00000000-0000-4000-a000-0000000016a1'
\set n_dos  '00000000-0000-4000-a000-0000000016a2'
\set n_tres '00000000-0000-4000-a000-0000000016a3'
\if :{?dueno}
\else
\set dueno '00000000-0000-4000-a000-000000000001'
\endif
select fn_fecha_miami(now()) as hoy \gset
select set_config('f16.hoy', :'hoy', false) is not null as ok, set_config('f16.n_uno', :'n_uno', false) is not null as ok1,
       set_config('f16.n_dos', :'n_dos', false) is not null as ok2, set_config('f16.n_tres', :'n_tres', false) is not null as ok3 \gset
select (to_regprocedure('public.fn_nomina_importar(jsonb,jsonb)') is not null) as hay_c15 \gset
\if :hay_c15
-- (a) el SQL Editor: las tres personas (su usuario y su perfil de campo), su tarifa y sus horas aprobadas de los dos períodos
begin;
insert into auth.users (id, email) values
  (:'n_uno',  'f16-n1@f16-pruebas.invalid'), (:'n_dos', 'f16-n2@f16-pruebas.invalid'), (:'n_tres', 'f16-n3@f16-pruebas.invalid')
on conflict (id) do nothing;
insert into perfiles (id, nombre, rol, activo) values
  (:'n_uno', 'ZZ Nomina Uno', 'campo', true), (:'n_dos', 'ZZ Nomina Dos', 'campo', true), (:'n_tres', 'ZZ Oficial Tres', 'campo', true)
on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
insert into costos_equipo (usuario_id, costo_hora) values (:'n_uno', 23), (:'n_dos', 20)
on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;
-- (horas aprobadas por el dueño: Uno 84 h —12 h siete días—, Dos 76 h —9.5 h ocho días—, el oficial 16 h en obra; en cada período)
insert into horas (fecha, usuario_id, proyecto_id, horas, notas, aprobado_por, aprobado_el)
select p.d0 + x.k, x.u::uuid, x.obra, x.h, 'ZZ f16: horas de la nómina', :'dueno'::uuid, now()
  from (values (:'hoy'::date - 28), (:'hoy'::date - 14)) p(d0)
  cross join lateral (
    select g.k, :'n_uno' as u, case when g.k % 2 = 0 then 'zz-nave-cuatro-a1b2' else 'zz-casa-cinco-c3d4' end as obra, 12.0 as h
      from generate_series(0, 6) g(k)
    union all
    select g.k, :'n_dos', 'zz-nave-cuatro-a1b2', 9.5 from generate_series(0, 7) g(k)
    union all
    select g.k, :'n_tres', 'zz-nave-cuatro-a1b2', 8.0 from generate_series(1, 2) g(k)) x;
commit;

-- (b) el dueño, con su código: la cuenta de lo sin obra, las dos nóminas (importar, enlazar, postear)
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
select fn_nomina_config(jsonb_build_object('cuenta_sin_obra', '6000')) is not null as ok \gset
do $$
declare
  hoy  date := current_setting('f16.hoy')::date;
  cab  text := 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Regular hours,'
               'Regular earnings,Overtime hours,Overtime earnings,Gross earnings,Employee federal income tax,Employee social security tax,'
               'Employee medicare tax,Employee medicare additional tax,Employee taxes,Employee deductions,Net pay,Reimbursements,Check amount,'
               'Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes,Employer cost';
  us   text;
  csv  text;
  r    jsonb;
  c    uuid;
  n    int;
  v_per record;
begin
  for v_per in select * from (values
      ('a', hoy - 28, hoy - 15, hoy - 11,
       array['ZZ Nomina,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1840.00,4.00,207.00,2047.00,150.00,126.91,29.68,0.00,306.59,0.00,1740.41,0.00,1740.41,126.91,29.68,12.28,55.27,224.14,2271.14',
             'ZZ Nomina,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,76.00,1520.00,0.00,0.00,1520.00,102.00,94.24,22.04,0.00,218.28,40.00,1261.72,0.00,1261.72,94.24,22.04,9.12,41.04,166.44,1686.44',
             'ZZ Oficial,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2600.00,0.00,0.00,2600.00,290.00,161.20,37.70,0.00,488.90,0.00,2111.10,58.40,2169.50,161.20,37.70,15.60,70.20,284.70,2884.70',
             'Totals,,,,,,,236.00,5960.00,4.00,207.00,6167.00,542.00,382.35,89.42,0.00,1013.77,40.00,5113.23,58.40,5171.63,382.35,89.42,37.00,166.51,675.28,6842.28']),
      ('b', hoy - 14, hoy - 1, hoy + 3,
       array['ZZ Nomina,Uno,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,1840.00,0.00,0.00,1840.00,128.00,114.08,26.68,0.00,268.76,0.00,1571.24,0.00,1571.24,114.08,26.68,11.04,49.68,201.48,2041.48',
             'ZZ Nomina,Dos,%1$s,%2$s,%3$s,Regular,Direct Deposit,76.00,1520.00,0.00,0.00,1520.00,102.00,94.24,22.04,0.00,218.28,40.00,1261.72,0.00,1261.72,94.24,22.04,9.12,41.04,166.44,1686.44',
             'ZZ Oficial,Tres,%1$s,%2$s,%3$s,Regular,Direct Deposit,80.00,2600.00,0.00,0.00,2600.00,290.00,161.20,37.70,0.00,488.90,0.00,2111.10,58.40,2169.50,161.20,37.70,15.60,70.20,284.70,2884.70',
             'Totals,,,,,,,236.00,5960.00,0.00,0.00,5960.00,520.00,369.52,86.42,0.00,975.94,40.00,4944.06,58.40,5002.46,369.52,86.42,35.76,160.92,652.62,6612.62'])
    ) x(k, desde, hasta, pago, filas) loop
    csv := cab || E'\n' || (select string_agg(format(f, to_char(v_per.desde, 'MM/DD/YYYY'), to_char(v_per.hasta, 'MM/DD/YYYY'),
                                                     to_char(v_per.pago, 'MM/DD/YYYY')), E'\n' order by o)
                              from unnest(v_per.filas) with ordinality u(f, o)) || E'\n';
    r := fn_nomina_importar(jsonb_build_object(
           'nombre', 'zz-f16-payroll-journal-' || v_per.k || '.csv', 'sha256', encode(sha256(convert_to(csv, 'UTF8')), 'hex'),
           'bytes', octet_length(csv),
           'filas', (select jsonb_agg(to_jsonb(string_to_array(l, ',')) order by o)
                       from unnest(string_to_array(rtrim(csv, E'\n'), E'\n')) with ordinality u(l, o))), '{}'::jsonb);
    c := (select (q ->> 'corrida')::uuid from jsonb_array_elements(r -> 'corridas') q where q ->> 'resultado' = 'nueva' limit 1);
    if c is null then
      raise exception 'f16-semilla: la nómina % no entró: %', v_per.k, left(r::text, 400);
    end if;
    if v_per.k = 'a' then
      perform fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('ZZ Nomina Uno')),
                                                   'usuario_id', current_setting('f16.n_uno'), 'clase', 'campo', 'confirmar', true));
      perform fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('ZZ Nomina Dos')),
                                                   'usuario_id', current_setting('f16.n_dos'), 'clase', 'campo', 'confirmar', true));
      perform fn_nomina_persona(jsonb_build_object('id', (select id from nomina_personas where clave = fn_nomina_clave('ZZ Oficial Tres')),
                                                   'usuario_id', current_setting('f16.n_tres'), 'clase', 'oficial', 'confirmar', true));
    end if;
    perform fn_nomina_postear(c, fn_nomina_propuesta(c) ->> 'visto');
  end loop;
end $$;
commit;

-- (c) Plaid trae los cargos de Gusto de la nómina A (dos días antes de su día de pago; nunca antes del día 1 del mes de hoy)
begin;
create temp table _zz_gusto on commit drop as
select '1010'::text as cuenta, 'zz-gusto-' || x.k as id, greatest(:'hoy'::date - 13, date_trunc('month', :'hoy'::date)::date) as fecha,
       x.monto, x.descr, 'DEBIT'::text as tipo
  from (values ('net', -5171.63, 'GUSTO DES:NET 99F16A ID:ZZF16NET'), ('tax', -1522.54, 'GUSTO DES:TAX 99F16A ID:ZZF16TAX'),
               ('sui', -166.51, 'GUSTO DES:TAX 99F16S ID:ZZF16SUI'), ('csd', -40.00, 'GUSTO DES:CSD 99F16A ID:ZZF16CSD')) x(k, monto, descr);
select fn_plaid_recibir('item-zz-f16-uno', jsonb_build_array(jsonb_build_object(
         'origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · ZZ Banco Uno · 1010',
         'plaid_saldo', ((select sum(l.monto) from asiento_lineas l join asientos a on a.id = l.asiento_id where l.cuenta = '1010' and a.tipo = 'apertura')
                         + (select coalesce(sum(m.monto), 0) from movimientos_banco m where m.cuenta = '1010')
                         + (select sum(g.monto) from _zz_gusto g))::text,
         'saldo_al', :'hoy',
         'filas', (select jsonb_agg(jsonb_build_object('id', g.id, 'fecha', g.fecha::text, 'plaid_monto', (-g.monto)::text,
                                                       'descripcion', g.descr, 'tipo', g.tipo, 'pendiente', false) order by g.id)
                     from _zz_gusto g))), 'cursor-zz-f16-gusto', '{"por": "f16-semilla: la nómina de Gusto"}') is not null as ok \gset
commit;

-- (d) el dueño, con su código: casa el neto y los impuestos de la nómina A desde Nómina → Cargos de Gusto
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'dueno', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', :'dueno', true) \gset
set local role authenticated;
do $$
declare
  ca uuid := (select k.id from nomina_corridas k where k.estado = 'posteada' order by k.dia_pago limit 1);
begin
  perform fn_nomina_cargo_casar((select id from movimientos_banco where id_externo = 'zz-gusto-net'),
            jsonb_build_array(jsonb_build_object('corrida', ca, 'cuenta', '2210', 'monto', '5171.63')), null);
  perform fn_nomina_cargo_casar((select id from movimientos_banco where id_externo = 'zz-gusto-tax'),
            jsonb_build_array(jsonb_build_object('corrida', ca, 'cuenta', '2220', 'monto', '1485.54'),
                              jsonb_build_object('corrida', ca, 'cuenta', '2225', 'monto', '37.00')), null);
end $$;
commit;
\endif
