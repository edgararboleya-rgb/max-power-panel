-- =====================================================================
-- f19-semilla.sql — la base de LA BANDEJA NUEVA (c17) y de LAS CUENTAS EN
-- INGLÉS (c18) para pruebas/conta/pantalla.js. SOLO PARA EL BANCO DE
-- PRUEBAS: NO se pega en Supabase. Todo inventado («ZZ …»): ni un nombre,
-- ni un monto, ni un número de verdad. Las marcas de comercios corrientes
-- (Home Depot, Netflix, Klarna, DoorDash, Wawa, Intuit, OnDeck) son las que
-- la Bandeja tiene que reconocer por su nombre.
--
-- Se pega como editor_sql (el SQL Editor) sobre un clon de g16a con las
-- capas del árbol encima (c3, c6, c10, c15, c16, c17 y c18: lo hace
-- f19-capturar.js), SIN «-1» (trae su transacción):
--   psql -X -q -v ON_ERROR_STOP=1 -U editor_sql -d <bd> -f pruebas/conta/f19-semilla.sql
--
-- «HOY». Todo se fecha en los doce días anteriores a hoy (en Miami): los
-- movimientos de la Bandeja son recientes, como los verá Edgar.
--
-- LO QUE SIEMBRA (cada cosa por el camino de su capa; nada entra al libro
-- por debajo):
--   · las tres obras de la semilla de siempre, con nombres «ZZ», y una
--     obra TERMINADA (ZZ Patio Sur); las dos personas del equipo, «ZZ»;
--   · cuatro facturas en el libro por su puente (c3): dos ya marcadas
--     cobradas en Proyectos que un procesador de tarjetas deposita juntas y
--     netas de su comisión; la de la obra terminada, marcada cobrada, que
--     paga el Zelle de una LLC; y una sin marcar, para elegirla a mano;
--   · horas de la cuadrilla: un día en UNA sola obra (la «obra del día») y
--     otro día en dos;
--   · un préstamo dado de alta (c6) con dos cuotas en el banco;
--   · LOS MOVIMIENTOS DEL BANCO que esperan en la Bandeja (por Plaid, c6):
--     cuatro cargos de Home Depot (dos el día de una sola obra), dos de
--     Netflix, Klarna, DoorDash, gasolina, un permiso del condado, el
--     depósito de un prestamista (OnDeck), el depósito del procesador
--     (Intuit) con dos facturas y su comisión, el Zelle de una LLC, un
--     depósito en efectivo por el cajero, un depósito sin nombre, un Zelle
--     a una persona, las dos cuotas del préstamo, dos cargos de intereses
--     de la tarjeta y un cargo con una propuesta de la IA (c8) pendiente;
--   · (segunda vuelta) lo que la revisión encontró y la pantalla tiene que
--     enseñar bien: el PAGO DE LA TARJETA desde el banco (lo que el banco
--     ya reconoce, dicho en llano y sin códigos); un SEGUNDO depósito del
--     procesador (los depósitos de un mismo pagador van juntos a la vista,
--     pero se contestan de uno en uno); dos cargos de «INTUIT» que NO son
--     lo mismo (su comisión por los pagos con tarjeta y la suscripción de
--     QuickBooks: cada uno va por su lado); dos cargos de la ciudad que
--     tampoco (un permiso y el recibo de la luz: un grupo «mezclado» no
--     propone nada); un movimiento a la
--     reserva que el banco no reconoce como traspaso (la puerta frena y
--     pide su porqué); y UNA TARJETA DE OBRA con tres compras cuyos recibos
--     «llegan después» (dos iguales el mismo día y una sola: f19-capturar.js
--     las registra desde la Bandeja y después sube sus recibos);
--   · (tercera vuelta) LO QUE PROPONE LA IA DE ANTES (c8), que en producción
--     es lo que dice buena parte de las tarjetas: además del gasto general
--     de la ferretería, un cargo PERSONAL (c8 lo manda al retiro del dueño,
--     con sus códigos en el motivo) y otro de la misma ferretería que ella
--     manda a una OBRA, firme (la tarjeta la trae puesta). Los dos de la
--     ferretería forman un grupo «mezclado» (no propone nada). El permiso y
--     la luz de la ciudad ya no forman grupo: son contrapartes distintas;
--   · (tercera vuelta) UNA COMIDA ya registrada (no espera en la Bandeja):
--     para que el paquete del año traiga la nota de las comidas en su línea.
-- Sus ids quedan en la tabla f19_semilla (clave → movimiento): la lee
-- f19-capturar.js. Se borra con la base.
-- =====================================================================
\set ON_ERROR_STOP on
begin;

create table if not exists public.f19_semilla (clave text primary key, movimiento uuid, nota text);
revoke all on public.f19_semilla from public, anon, authenticated, service_role;
-- (solo en el banco: quien captura como el dueño filtra la Bandeja por estos movimientos)
grant select on public.f19_semilla to authenticated;
truncate public.f19_semilla;

create or replace function pg_temp.s19_hoy() returns date language sql as $$ select fn_fecha_miami(now()) $$;
create or replace function pg_temp.s19_dueno() returns text language sql as $$
  select id::text from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1 $$;
-- un movimiento del banco como lo trae Plaid (en nombre del dueño) y «Casar» solo para él: queda pendiente en la Bandeja.
-- p_monto negativo = dinero que salió; positivo, un depósito. p_dias: hace cuántos días
create or replace function pg_temp.s19_mov(p_clave text, p_dias int, p_monto numeric, p_desc text, p_cuenta text default '1010')
returns uuid language plpgsql as $$
declare
  v_mov uuid;
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.s19_dueno(), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.s19_dueno(), true);
  perform fn_banco_importar_filas(jsonb_build_object(
    'origen', 'plaid', 'cuenta', p_cuenta, 'nombre', 'Plaid · f19-semilla · ' || p_clave,
    'filas', jsonb_build_array(jsonb_build_object(
               'id', 'ZZ19-' || p_clave, 'fecha', (pg_temp.s19_hoy() - p_dias)::text, 'plaid_monto', (-p_monto)::text, 'descripcion', p_desc,
               'tipo', case when p_monto > 0 then 'CREDIT' else 'DEBIT' end, 'pendiente', false))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = 'ZZ19-' || p_clave order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  insert into public.f19_semilla (clave, movimiento, nota) values (p_clave, v_mov, p_desc)
  on conflict (clave) do update set movimiento = excluded.movimiento, nota = excluded.nota;
  return v_mov;
end $$;

-- 1. Las obras y las personas, todo «ZZ»
update proyectos set nombre = 'ZZ Casa Roble', cliente = 'ZZ Cliente Roble', direccion = '1 ZZ St, Ocala, FL' where id = 'casa-perez-k3m9';
update proyectos set nombre = 'ZZ Oficina Norte', cliente = 'ZZ Cliente Norte', direccion = '2 ZZ Ave, Ocala, FL' where id = 'oficina-nch-7xq2';
update proyectos set nombre = 'ZZ Taller Tres', cliente = 'ZZ Cliente Taller', direccion = '3 ZZ Rd, Ocala, FL' where id = 'taller-ruiz-5b2n';
insert into proyectos (id, tipo, nombre, cliente, estado)
values ('zz-patio-sur', 'residencial', 'ZZ Patio Sur', 'ZZ Alfa Holdings LLC', 'completado')
on conflict (id) do nothing;
update perfiles set nombre = 'ZZ Ayudante ' || case when id = '00000000-0000-4000-a000-000000000002' then 'Uno' else 'Dos' end where rol <> 'dueno';
update perfiles set nombre = 'ZZ Dueño' where rol = 'dueno';

-- 2. Los mapeos que hacen que una factura entre al libro, el contador encendido y lejos de su tope, y lo de «entra solo» de fábrica
do $$
declare
  v_t text;
begin
  for v_t in select distinct fn_puente_normalizar(p.tipo) from proyectos p loop
    perform fn_mapeo_tipo_proyecto(v_t, coalesce((select mm.cuenta from mapeo_tipo_proyecto mm where mm.tipo = v_t),
                                                 case v_t when 'comercial' then '4020' when 'servicio' then '4030' else '4010' end));
  end loop;
  update contador_config set activa = true, tope_mes_centavos = 1000000 where id = 1;
  update asistente_ajustes set valor = '1000000' where clave = 'tope_mes_centavos';
end $$;

-- 3. Las facturas (ids negativos: no chocan con las de la semilla de siempre)
insert into facturas (id, proyecto_id, num, fecha, monto, retencion, pagada, cobrada_el) overriding system value values
  (-1900001, 'casa-perez-k3m9',  'ZZ-101', pg_temp.s19_hoy() - 20, 4180.25, 0, true,  ((pg_temp.s19_hoy() - 8) + time '12:00') at time zone 'America/New_York'),
  (-1900002, 'oficina-nch-7xq2', 'ZZ-102', pg_temp.s19_hoy() - 18, 7319.75, 0, true,  ((pg_temp.s19_hoy() - 8) + time '12:00') at time zone 'America/New_York'),
  (-1900003, 'zz-patio-sur',     'ZZ-103', pg_temp.s19_hoy() - 25, 2640.80, 0, true,  ((pg_temp.s19_hoy() - 7) + time '12:00') at time zone 'America/New_York'),
  (-1900004, 'taller-ruiz-5b2n', 'ZZ-104', pg_temp.s19_hoy() - 15, 1450.75, 0, false, null);
select fn_puentes_correr() is not null as puentes;

-- 4. Las horas de la cuadrilla: hace 6 días, en UNA sola obra; hace 4, en dos
insert into horas (id, fecha, usuario_id, proyecto_id, horas, notas) overriding system value values
  (-1900011, pg_temp.s19_hoy() - 6, '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 8, 'f19-semilla'),
  (-1900012, pg_temp.s19_hoy() - 6, '00000000-0000-4000-a000-000000000003', 'casa-perez-k3m9', 6, 'f19-semilla'),
  (-1900013, pg_temp.s19_hoy() - 4, '00000000-0000-4000-a000-000000000002', 'casa-perez-k3m9', 4, 'f19-semilla'),
  (-1900014, pg_temp.s19_hoy() - 4, '00000000-0000-4000-a000-000000000002', 'oficina-nch-7xq2', 4, 'f19-semilla');

-- 5. Un préstamo dado de alta (sus cuotas llegan por el banco)
select fn_prestamo_guardar(jsonb_build_object(
  'prestamista', 'ZZ Capital Uno', 'descripcion', 'f19-semilla: préstamo de prueba', 'principal', '25000.00', 'tasa_anual', '19.99',
  'cuota', '600.00', 'primer_pago', (pg_temp.s19_hoy() - 10)::text, 'dia_pago', 15, 'plazo_meses', 52, 'frecuencia', 'semanal',
  'cuenta', '2540', 'cuenta_largo', '2550', 'saldo_inicial', '25000.00', 'saldo_inicial_al', (pg_temp.s19_hoy() - 11)::text,
  'descriptor', 'ZZCAPITAL')) is not null as prestamo;

-- 6. Los movimientos del banco que esperan en la Bandeja
select pg_temp.s19_mov('hd1', 6,  -245.37,  'THE HOME DEPOT #6341 OCALA FL') is not null;
select pg_temp.s19_mov('hd2', 6,   -89.10,  'THE HOME DEPOT #6341 OCALA FL') is not null;
select pg_temp.s19_mov('hd3', 4, -1320.55,  'THE HOME DEPOT 6355 BELLEVIEW FL') is not null;
-- (tercera vuelta) un cuarto, un día sin horas de la cuadrilla: decidido el grupo con «la obra del día», se quedan DOS sin obra (el
-- grupo sigue, dice por qué y pide una obra para los dos)
select pg_temp.s19_mov('hd4', 3,   -76.20,  'THE HOME DEPOT 6355 BELLEVIEW FL') is not null;
select pg_temp.s19_mov('nf1', 12,  -15.49,  'NETFLIX.COM') is not null;
select pg_temp.s19_mov('nf2', 9,   -15.49,  'NETFLIX.COM') is not null;
select pg_temp.s19_mov('kl1', 3,   -45.00,  'KLARNA 8J2 PAYMENT') is not null;
select pg_temp.s19_mov('dd1', 3,   -32.18,  'DOORDASH*ZZ BURGER') is not null;
select pg_temp.s19_mov('ww1', 5,   -62.00,  'WAWA 5234 OCALA FL') is not null;
select pg_temp.s19_mov('pm1', 6,  -350.00,  'MARION COUNTY BOCC PERMITS') is not null;
select pg_temp.s19_mov('od1', 8, 25000.00,  'ORIG CO NAME:ONDECK CAPITAL ORIG ID:1234567890 DESC DATE:ZZ19') is not null;
-- (lo que llega es el neto: Intuit se queda el 2.99 % de CADA factura: $124.99 de la ZZ-101 y $218.86 de la ZZ-102)
select pg_temp.s19_mov('in1', 7, 11156.15,  'INTUIT 77788899 DEPOSIT') is not null;
select pg_temp.s19_mov('zl1', 7,  2640.80,  'ZELLE PAYMENT FROM ZZ ALFA HOLDINGS LLC 123456') is not null;
select pg_temp.s19_mov('at1', 5,   800.00,  'ATM CASH DEPOSIT 1234 ZZ MAIN ST') is not null;
select pg_temp.s19_mov('dp1', 5,  1000.00,  'DEPOSIT ID NUMBER 447102') is not null;
select pg_temp.s19_mov('zp1', 4,  -500.00,  'ZELLE PAYMENT TO ZZ JUAN PRUEBA JPM99ABC') is not null;
select pg_temp.s19_mov('cu1', 10, -600.00,  'ACH ZZCAPITAL PAYMENT 0001') is not null;
select pg_temp.s19_mov('cu2', 3,  -600.00,  'ACH ZZCAPITAL PAYMENT 0002') is not null;
select pg_temp.s19_mov('fe1', 2,   -88.40,  'ZZ FERRETERIA CENTRAL 0042') is not null;
select pg_temp.s19_mov('it1', 11,  -31.56,  'INTEREST CHARGE ON PURCHASES', '2100-2013') is not null;
select pg_temp.s19_mov('it2', 2,   -28.14,  'INTEREST CHARGE ON PURCHASES', '2100-2013') is not null;

-- 6b. (segunda vuelta) Lo que la revisión encontró
-- el pago de la tarjeta desde el banco; otro depósito del procesador (sin factura que cuadre: se pregunta); la comisión del
-- procesador y la suscripción de QuickBooks (los dos dicen «INTUIT» y no son lo mismo); y dinero que se pasa a la reserva
select pg_temp.s19_mov('tj1', 9,  -430.89,  'AMEX EPAYMENT ACH PMT ZZ1234') is not null;
select pg_temp.s19_mov('in2', 2,  1300.00,  'INTUIT 77788899 DEPOSIT') is not null;
select pg_temp.s19_mov('if1', 7,   -44.10,  'INTUIT 77788899 TRAN FEE') is not null;
select pg_temp.s19_mov('iq1', 8,   -99.00,  'INTUIT *QBOOKS ONLINE') is not null;
select pg_temp.s19_mov('tr1', 2, -2000.13,  'ZZ MOVIMIENTO A LA RESERVA') is not null;
-- dos cargos de la ciudad que NO son lo mismo (un permiso de obra y el recibo de la luz): su grupo no propone nada
select pg_temp.s19_mov('co1', 8,  -125.00,  'CITY OF OCALA BLDG PERMIT 0091') is not null;
select pg_temp.s19_mov('co2', 3,  -210.40,  'CITY OF OCALA UTILITIES') is not null;
-- dinero a una cuenta que la app no conoce: lo que dice el banco trae una orden para el SQL Editor (la tarjeta no la enseña)
select pg_temp.s19_mov('cd1', 3,  -300.00,  'ONLINE TRANSFER TO CHK ...4456 TRANSACTION#: 99887766') is not null;
-- UNA TARJETA DE OBRA (la que lleva la cuadrilla): sus compras llegan por el banco y sus recibos, por la app. Dos compras iguales
-- el mismo día (el banco pregunta si la segunda es la misma: Edgar dice que no) y una sola
insert into cuentas (codigo, nombre, nombre_en, tipo, saldo_normal, imputable, regla_obra, regla_cost_code)
values ('2100-9919', 'ZZ Tarjeta de obra', 'ZZ Job card', 'pasivo', 'haber', true, 'prohibida', 'prohibida')
on conflict (codigo) do nothing;
select fn_tarjeta_alta('9919', '2100-9919', 'f19-semilla: la tarjeta de obra') is not null as tarjeta;
select fn_mapeo_categoria('material', '5100') is not null, fn_mapeo_metodo_pago('credito', 'tarjeta') is not null;
-- un subcontratista dado de alta (a quién se le paga un subcontrato: con su nombre, el pago sale en su 1099)
select fn_proveedor_alta('ZZ Azulejos Sur', 'Net 30', array['zz azulejos sur llc']) is not null as proveedor;
select pg_temp.s19_mov('rc1', 5,   -64.37,  'ZZ MADERAS DEL SUR 0042 OCALA FL', '2100-9919') is not null;
select pg_temp.s19_mov('rc2', 5,   -64.37,  'ZZ MADERAS DEL SUR 0042 OCALA FL', '2100-9919') is not null;
select pg_temp.s19_mov('rc3', 4,   -77.31,  'ZZ ELECTRICA TOTAL 0007 OCALA FL', '2100-9919') is not null;
do $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.s19_dueno(), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.s19_dueno(), true);
  perform fn_banco_duplicado(s.movimiento, false, 'f19-semilla: fueron dos compras iguales el mismo día')
     from public.f19_semilla s join movimientos_banco m on m.id = s.movimiento
    where s.clave in ('rc1', 'rc2') and m.posible_duplicado_de is not null and m.duplicado is null;
  perform fn_banco_casar(s.movimiento) from public.f19_semilla s where s.clave in ('rc1', 'rc2');
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

-- 6c. (tercera vuelta) Dos cargos más para los que la IA de antes (c8) tiene su propuesta: uno personal y otro de la misma
--     ferretería, que ella manda a una obra (los dos de la ferretería forman un grupo «mezclado»: sus tarjetas no dicen lo mismo)
select pg_temp.s19_mov('ia2', 2,   -17.99,  'ZZ CINE CLUB 0042') is not null;
select pg_temp.s19_mov('ia3', 1,  -412.60,  'ZZ FERRETERIA CENTRAL 0042') is not null;
-- y un comercio cuyo nombre es UNA palabra de más de cuarenta letras (los rótulos de su tarjeta la parten; no la ensanchan)
select pg_temp.s19_mov('lg1', 1,   -53.27,  'ZZSUPERDISTRIBUIDORAELECTRICADELCENTRODEFLORIDA 0042') is not null;

-- 6d. (tercera vuelta) UNA COMIDA ya en el libro (clasificada en el banco de siempre, no por la Bandeja: no espera ni sale en lo
--     contestado): el paquete del año la lleva en su línea al 100 % de libros, y en su renglón dice que solo la mitad es deducible
do $$
declare
  v uuid;
begin
  v := pg_temp.s19_mov('cm1', 9, -84.60, 'ZZ FONDA LA OBRA 0042');
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.s19_dueno(), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.s19_dueno(), true);
  perform fn_banco_clasificar(v, '[{"cuenta": "6350"}]'::jsonb, null);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

-- 7. Las propuestas de la IA (c8) pendientes: el cargo de la ferretería (un gasto general) y, tercera vuelta, lo que en producción
--    dice buena parte de las tarjetas: algo personal (c8 lo manda siempre al retiro del dueño, con su jerga en el motivo) y un
--    gasto de obra con la obra que ella propone, firme (flags.obra_fuerte: la única que se preselecciona)
with l as (
  insert into contador_lotes (modelo, effort, prompt_version, n, usage, centavos, por, cerrado_el)
  values ('claude-opus-5-5', 'low', 'f19-semilla', 3, '{"input": 3600, "output": 270}', 3, pg_temp.s19_dueno()::uuid, now())
  returning id)
insert into contador_propuestas (movimiento_id, fuente, lote_id, modelo, effort, prompt_version, propuesta, estado)
select (select movimiento from public.f19_semilla where clave = x.clave), 'ia', l.id, 'claude-opus-5-5', 'low', 'f19-semilla', x.propuesta, 'pendiente'
  from l, (values
    ('fe1', '{"lineas": [{"cuenta": "6400"}], "motivo": "una ferretería: herramienta menor", "confianza": 0.86}'::jsonb),
    ('ia2', '{"lineas": [{"cuenta": "3200"}], "motivo": "Una suscripción de cine es personal: va a distribuciones (3200), no a gasto de la empresa.", "confianza": 0.9, "flags": {"personal": true}}'::jsonb),
    ('ia3', '{"lineas": [{"cuenta": "5100", "proyecto_id": "oficina-nch-7xq2"}], "motivo": "Material eléctrico (5100) para la obra donde estuvo la cuadrilla esa semana.", "confianza": 0.84, "flags": {"obra_propuesta": true, "obra_fuerte": true}, "obra": {"proyecto_id": "oficina-nch-7xq2", "confianza": 0.86, "motivo": "las horas de esa semana"}}'::jsonb)
  ) as x(clave, propuesta);

commit;

-- lo sembrado, a la vista
select s.clave, m.fecha, m.monto, left(m.descripcion, 40) as descripcion, m.estado, m.propuesta->>'motivo' as motivo
  from public.f19_semilla s join movimientos_banco m on m.id = s.movimiento
 order by m.fecha, s.clave;
