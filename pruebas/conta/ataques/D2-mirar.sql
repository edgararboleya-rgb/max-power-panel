\pset format aligned
\pset pager off
select fn_prestamo_guardar('{"prestamista": "Edgar", "descripcion": "x", "principal": "1000.00", "tasa_anual": "0", "cuota": "100.00", "primer_pago": "2026-11-15", "dia_pago": 15, "plazo_meses": 10, "saldo_inicial": "1000.00", "saldo_inicial_al": "2026-10-31", "cuenta": "1130"}') ->> 'prestamista' as prestamo_1130;
select fn_prestamo_guardar('{"prestamista": "Edgar", "descripcion": "x", "principal": "1000.00", "tasa_anual": "0", "cuota": "100.00", "primer_pago": "2026-11-15", "dia_pago": 15, "plazo_meses": 10, "saldo_inicial": "1000.00", "saldo_inicial_al": "2026-10-31", "cuenta": "2900"}') ->> 'prestamista' as prestamo_2900;
select fn_prestamo_guardar('{"prestamista": "Edgar", "descripcion": "x", "principal": "1000.00", "tasa_anual": "0", "cuota": "100.00", "primer_pago": "2026-11-15", "dia_pago": 15, "plazo_meses": 10, "saldo_inicial": "1000.00", "saldo_inicial_al": "2026-10-31", "cuenta": "2520", "cuenta_largo": "3100"}') ->> 'prestamista' as prestamo_largo_3100;
select pol.polname, pol.polcmd::text, pg_get_expr(pol.polqual, pol.polrelid), pol.polroles::regrole[] from pg_policy pol where pol.polrelid = 'banco_cuentas_personales'::regclass;
select c.relrowsecurity, has_table_privilege('anon', c.oid, 'select') as anon_sel, has_table_privilege('authenticated', c.oid, 'select') as auth_sel,
       has_table_privilege('authenticated', c.oid, 'insert') as auth_ins, has_table_privilege('authenticated', c.oid, 'update') as auth_upd
  from pg_class c where c.relname = 'banco_cuentas_personales';
-- el equipo (Gustavo) y anon leen 0 filas; Edgar las ve
select fn_banco_cuenta_personal('7781', 'Chase personal de Edgar') ->> 'ultimos4' as alta;
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select count(*) as equipo_ve from banco_cuentas_personales;
rollback;
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select count(*) as dueno_ve from banco_cuentas_personales;
select fn_banco_cuenta_personal('5512', 'desde la app') as desde_la_app;
rollback;
begin;
set local role anon;
select count(*) as anon_ve from banco_cuentas_personales;
rollback;
select column_name from information_schema.columns where table_name = 'banco_historial' order by ordinal_position;
