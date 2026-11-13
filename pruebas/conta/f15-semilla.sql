-- =====================================================================
-- f15-semilla.sql — la base de la Fase 11 (la nómina, c15) para la pantalla
-- (pantalla.js): tres personas de nómina, dos obras, sus horas de un período
-- de pago de octubre de 2026 y los cargos de Gusto en el banco. SOLO PARA EL
-- BANCO DE PRUEBAS: NO se pega en Supabase. Todo inventado («ZZ …» y
-- «C15 PRUEBA …»): ni un nombre, ni un monto, ni un número de nadie.
--
-- La pega pruebas/conta/f15-capturar.js como editor_sql (el SQL Editor), sobre
-- un clon de g12a con c15-nomina.sql pegado; la parte del dueño (traer los
-- cargos de Gusto del banco, como lo hace Plaid) cambia de rol dentro de su
-- transacción. Después el capturador hace, en el mismo orden que la prueba de
-- la pantalla, cada cosa que la pantalla escribe, y guarda lo que contesta el
-- banco en pruebas/conta/pantalla-f15.json (la base simulada de la página).
--
-- EL PERÍODO DE PAGO: del lunes 5 al domingo 18 de octubre de 2026 (dos
-- semanas laborales enteras, la semana empieza en lunes); día de pago, el
-- viernes 23; los cargos de Gusto, el lunes 19 (cuatro días hábiles antes);
-- la cuota mensual, el 2. Las horas:
--   ZZ Ayudante Uno   6-oct 8 h obra A · 7-oct 8 h obra A · 8-oct 10 h obra B
--                     «CO #1» · 9-oct 4 h SIN OBRA (aprobadas) · y la
--                     segunda semana 12 a 16-oct 10+10+10+10+4 h (aprobadas:
--                     44 h, 4 extra) · 17-oct 3 h obra B SIN APROBAR
--   ZZ Ayudante Dos   6-oct 8 h obra B SIN APROBAR (ninguna aprobada: su
--                     corrida frena hasta que se decida)
--   ZZ Oficial Tres   7-oct 10 h obra A · 8-oct 10 h obra A (aprobadas; es el
--                     accionista-oficial, de sueldo fijo)
-- Los nombres de la semilla vieja del banco (dos perfiles y tres obras) se
-- cambian por inventados: salen en las tablas de horas de la pantalla.
-- =====================================================================
\set ON_ERROR_STOP 1
\set QUIET 1
\set uno  '00000000-0000-4000-a000-0000000015a1'
\set dos  '00000000-0000-4000-a000-0000000015a2'
\set tres '00000000-0000-4000-a000-0000000015a3'

-- ===== 1. el SQL Editor: los nombres viejos del banco, las personas, las obras y sus horas
begin;
update perfiles set nombre = 'ZZ Equipo Dos'  where id = '00000000-0000-4000-a000-000000000002';
update perfiles set nombre = 'ZZ Equipo Tres' where id = '00000000-0000-4000-a000-000000000003';
update proyectos set nombre = 'ZZ Casa Uno'    where id = 'casa-perez-k3m9';
update proyectos set nombre = 'ZZ Oficina Dos' where id = 'oficina-nch-7xq2';
update proyectos set nombre = 'ZZ Taller Tres' where id = 'taller-ruiz-5b2n';

insert into auth.users (id, email) values
  (:'uno',  'c15-p1@c15-pruebas.invalid'),
  (:'dos',  'c15-p2@c15-pruebas.invalid'),
  (:'tres', 'c15-p3@c15-pruebas.invalid')
on conflict (id) do nothing;
insert into perfiles (id, nombre, rol, activo) values
  (:'uno',  'ZZ Ayudante Uno', 'campo', true),
  (:'dos',  'ZZ Ayudante Dos', 'campo', true),
  (:'tres', 'ZZ Oficial Tres', 'campo', true)
on conflict (id) do update set nombre = excluded.nombre, rol = excluded.rol, activo = true;
insert into costos_equipo (usuario_id, costo_hora) values (:'uno', 25), (:'dos', 30)
on conflict (usuario_id) do update set costo_hora = excluded.costo_hora;

insert into proyectos (id, tipo, nombre, estado) values
  ('c15-prueba-a', 'comercial', 'C15 PRUEBA Obra A', 'ejecucion'),
  ('c15-prueba-b', 'servicio',  'C15 PRUEBA Obra B', 'ejecucion')
on conflict (id) do nothing;

insert into horas (id, fecha, usuario_id, proyecto_id, horas, co, notas, aprobado_por, aprobado_el) overriding system value values
  (-1510000101, '2026-10-06', :'uno',  'c15-prueba-a', 8,  null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-10 15:00+00'),
  (-1510000102, '2026-10-07', :'uno',  'c15-prueba-a', 8,  null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-10 15:00+00'),
  (-1510000103, '2026-10-08', :'uno',  'c15-prueba-b', 10, 'CO #1', 'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-10 15:00+00'),
  (-1510000104, '2026-10-09', :'uno',  null,           4,  null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-10 15:00+00'),
  (-1510000105, '2026-10-12', :'uno',  'c15-prueba-a', 10, null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-17 15:00+00'),
  (-1510000106, '2026-10-13', :'uno',  'c15-prueba-a', 10, null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-17 15:00+00'),
  (-1510000107, '2026-10-14', :'uno',  'c15-prueba-b', 10, null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-17 15:00+00'),
  (-1510000108, '2026-10-15', :'uno',  'c15-prueba-b', 10, null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-17 15:00+00'),
  (-1510000109, '2026-10-16', :'uno',  'c15-prueba-a', 4,  null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-17 15:00+00'),
  (-1510000110, '2026-10-17', :'uno',  'c15-prueba-b', 3,  null,    'c15-pantalla', null, null),
  (-1510000111, '2026-10-06', :'dos',  'c15-prueba-b', 8,  null,    'c15-pantalla', null, null),
  (-1510000112, '2026-10-07', :'tres', 'c15-prueba-a', 10, null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-10 15:00+00'),
  (-1510000113, '2026-10-08', :'tres', 'c15-prueba-a', 10, null,    'c15-pantalla', '00000000-0000-4000-a000-000000000001', '2026-10-10 15:00+00')
on conflict (id) do nothing;
commit;

-- ===== 2. el dueño por la API (como Plaid): los cargos de Gusto en la cuenta operativa. c6 los deja en la Bandeja esperando su journal
begin;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-a000-000000000001', 'role', 'authenticated', 'aal', 'aal2')::text, true) \gset
select set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-000000000001', true) \gset
set local role authenticated;
select fn_banco_importar_filas(jsonb_build_object(
  'origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · c15 pantalla',
  'filas', jsonb_build_array(
    jsonb_build_object('id', 'c15-pantalla-fee', 'fecha', '2026-10-02', 'plaid_monto', '49.00',   'descripcion', 'GUSTO FEE 6semk7 C15 PRUEBA', 'tipo', 'DEBIT', 'pendiente', false),
    jsonb_build_object('id', 'c15-pantalla-net', 'fecha', '2026-10-19', 'plaid_monto', '4874.93', 'descripcion', 'GUSTO NET 6semk7 C15 PRUEBA', 'tipo', 'DEBIT', 'pendiente', false),
    jsonb_build_object('id', 'c15-pantalla-tax', 'fecha', '2026-10-19', 'plaid_monto', '1583.31', 'descripcion', 'GUSTO TAX 6semk7 C15 PRUEBA', 'tipo', 'DEBIT', 'pendiente', false),
    jsonb_build_object('id', 'c15-pantalla-csd', 'fecha', '2026-10-19', 'plaid_monto', '50.00',   'descripcion', 'GUSTO CSD 6semk7 C15 PRUEBA', 'tipo', 'DEBIT', 'pendiente', false)))) \gset
select count(fn_banco_casar(m.id)) as casados from movimientos_banco m where m.id_externo like 'c15-pantalla-%' \gset
commit;
