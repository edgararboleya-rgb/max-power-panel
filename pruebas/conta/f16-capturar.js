/* f16-capturar.js — LA BASE SIMULADA del tablero de la portada «Resumen» de
   Contabilidad (c16) de pruebas/conta/pantalla.js, SACADA DEL BANCO.

   No hay una mentira escrita a mano para el tablero: cada respuesta de
   fn_tablero que la pantalla recibe en pantalla.js es la que dio el banco
   (Postgres 17 en 127.0.0.1:5433) a la misma llamada, como el dueño
   (authenticated, aal2). Este script:
     1. arma <bd> (BORRA la que haya con ese nombre): un clon de la plantilla
        (de fábrica g16a desde el 14-nov: producción con la lista v305, y
        encima las capas de la 11c; antes, g12a) con
        f16-semilla.sql (un libro en uso de la apertura al 30-sep a HOY,
        inventado) y c16-tablero.sql; <bd>_m, igual pero con «hoy» fingido
        en el 10-mar-2027 (la semilla lo sabe hacer: -v hoy=…), para ver las
        gráficas con varios meses de libro; <bd>_o, con «hoy» en el
        20-ene-2027 (el primer mes del año nuevo, ya sin QuickBooks: las
        ventas del año tienen un solo mes y van en cifra sola, sin una
        gráfica de una columna); y <bd>_p, la plantilla con c16 y
        SIN semilla: producción tal como la verá Edgar al pegar c16 (sin la
        apertura en el libro; solo los nombres de sus tres obras pasan a
        «ZZ», como los deja la semilla);
     2. le pide a fn_tablero, como el dueño, lo que la pantalla pide: el
        tablero entero; la tarjeta de resultados con cada período del
        selector (este mes, el mes pasado, el año, el año pasado), la de
        ventas con el año anterior (el segundo botón de su tarjeta); el
        tablero con un tope
        por reloj corto (lo que no alcanzó sale en «sigue») y la segunda
        llamada con lo que siguió; y, en transacciones que se deshacen, el
        tablero con dos capas que no están (sin los préstamos de c6 ni los
        cobros en línea de p1) y con una tarjeta que falla sola (el use tax,
        sin permiso de leer su vista: 42501); más los errores (el equipo,
        42501; una tarjeta que no existe, 22023); y, también en transacciones
        que se deshacen, dos escenas «aparte»: un cobro de Stripe ya
        depositado y reembolsado en parte después (lo que Stripe descontará
        del siguiente depósito; en <bd>) y una renta pagada desde el banco en
        producción sin la apertura (la caja en rojo sin alarma falsa; en
        <bd>_p); y la caja y las ventas el 20-oct-2026, el primer mes del
        libro (el reloj de <bd> vuelto a ese día dentro de la transacción: un
        solo mes, la cifra sola); y un cheque de hace 40 días que rebota hace
        5 (lo devuelto de un cobro de antes, que no está restado de lo
        cobrado en los 30 días: va aparte; en <bd>);
     3. comprueba que pedir unas tarjetas sueltas da lo mismo que esas
        tarjetas en el tablero entero (salvo «ms»): así la pantalla.js puede
        contestar a «Personalizar» (pide solo las que se ven) con el tablero
        entero, y lo dice en el JSON;
     4. revisa que en lo capturado no salga ningún nombre de la semilla de
        siempre (sin distinguir mayúsculas; los ids de obra de 02-semilla.sql,
        como «casa-perez-k3m9», son ids inventados que ya son públicos: se
        comprueba que estén en 02-semilla.sql y se quitan antes de revisar);
     5. escribe pruebas/conta/pantalla-f16.json.
   Los números son los del banco el día en que se capturó (lo que depende de
   «hoy» es de ese día): la pantalla los enseña tal cual. Si c16 o la semilla
   cambian, se vuelve a correr y pantalla.js sigue con lo nuevo (comprueba la
   huella de los dos archivos).

   (14-nov, Fase 11c: EL TABLERO APRENDE LA NÓMINA) La plantilla de fábrica
   es ahora g16a (producción cuando Edgar pegue la lista v305: c15 dentro) y,
   encima, las capas del árbol que cambian en la 11c, en el orden en que las
   pega Edgar (CAPAS: c3, c6 en dos partes, c10, c15; c16 al final), cada una
   con su huella en el JSON (pantalla.js las compara). La semilla trae una
   nómina de Gusto DE VERDAD (c15: dos nóminas posteadas, una con día de pago
   después de hoy, cargos de Gusto casados y otros esperando), y se capturan
   además: el tablero entero SIN el código del teléfono (aal1: «sin_codigo»),
   y, en transacciones que se deshacen, la base SIN c15 (sus vistas quitadas:
   la tarjeta dice que falta, la acción no está disponible y la caja como
   antes), una nómina de UNA persona posteada después de la última (un bono:
   con y sin el código) y una nómina importada SIN POSTEAR (con y sin el
   código). (C16=<archivo> y SEMILLA_NOMINA=<archivo> dejan probar otro c16
   u otra semilla de la nómina; el JSON guarda la huella de lo que se usó y
   pantalla.js la compara con la del árbol: la base simulada de verdad se
   saca sin ellos.)
   Y CON EL c16 DE VERDAD (marca 2026111402; la pantalla se hizo antes contra
   un prototipo): además, en transacciones que se deshacen, el CRITERIO
   «codigo» de la nómina (sin el código no se escribe su dinero: la tarjeta,
   gastos y la proyección; con el código da lo mismo que «libro», y se
   comprueba), la cuenta de REEMBOLSOS A EMPLEADOS AL REVÉS (va aparte), la
   PRÓXIMA IMPORTADA sin postear (con y sin el código) y un cargo de Gusto
   DES-CASADO en la Bandeja (su cuadre en rojo; con y sin el código).
   Y CON EL c16 DE LOS ARREGLOS DE LA VERIFICACIÓN (marca 2026111403): unas
   VACACIONES DEVENGADAS a mano (400.00 en la 2215, del renglón «nómina por
   pagar» del Balance): no son de la nómina de Gusto, así que lo que se
   debe de ella y cuándo sale no cambian; van aparte («otras»), y la caja
   las deja en lo que no incluye.

   Uso (solo el banco; nada de red):
     node pruebas/conta/f16-capturar.js <bd> [plantilla=g16a]
   Tarda unos 25 s. Las cuatro bases quedan; se borran a mano:
     runuser -u postgres -- psql -X -h /var/run/postgresql -p 5433 -c "drop database <bd>" (y <bd>_m, <bd>_o y <bd>_p). */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { execFileSync } = require('child_process');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--'));
const BD = ARGS[0], PLANTILLA = ARGS[1] || 'g16a', BDM = BD + '_m', HOY_M = '2027-03-10', BDO = BD + '_o', HOY_O = '2027-01-20', BDP = BD + '_p';
const SAGRADAS = ['g16a', 'g15a', 'g12a', 'g10a', 'g9a', 'g8a', 'f9fix', 'p1fab', 'c9perf', PLANTILLA];
if (!BD || !/^[a-z][a-z0-9_]*$/.test(BD) || [BD, BDM, BDO, BDP].some(x => SAGRADAS.includes(x))) {
  console.error('uso: node pruebas/conta/f16-capturar.js <bd nueva> [plantilla=g16a]   (nunca una plantilla)'); process.exit(2);
}
const ROOT = path.resolve(__dirname, '..', '..');
const SALIDA = path.join(__dirname, 'pantalla-f16.json');
const ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT: '5433', PGPASSWORD: 'editor_sql' };
const DUENO = '00000000-0000-4000-a000-000000000001', EQUIPO = '00000000-0000-4000-a000-000000000002';
const huella = f => crypto.createHash('sha1').update(fs.readFileSync(path.isAbsolute(f) ? f : path.join(ROOT, f))).digest('hex').slice(0, 12);
// (11c) las capas del árbol que cambian en la Fase 11c, en el orden de Edgar (encima de la plantilla), y c16 al final
const CAPAS = ['docs/conta/c3-puentes.sql', 'docs/conta/c6-banco-parte1.sql', 'docs/conta/c6-banco-parte2.sql', 'docs/conta/c10-costo-obra.sql',
  'docs/conta/c15-nomina.sql'];
// (11c) el c16 y la semilla de la nómina: los del árbol, o los que se digan (el prototipo, mientras no estén en el árbol)
const C16 = process.env.C16 ? path.resolve(process.env.C16) : path.join(ROOT, 'docs/conta/c16-tablero.sql');
const SEMILLA_NOM = process.env.SEMILLA_NOMINA ? path.resolve(process.env.SEMILLA_NOMINA) : null;
if (!SEMILLA_NOM && !fs.readFileSync(path.join(__dirname, 'f16-semilla.sql'), 'utf8').includes('LA NÓMINA DE GUSTO (c15)'))
  console.warn('OJO: f16-semilla.sql no trae la nómina de Gusto (c15) y no se dijo SEMILLA_NOMINA=<archivo>: la tarjeta de la nómina saldrá sin nóminas.');

// ---------- el banco ----------
const su = sql => execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', '5433', '-v', 'ON_ERROR_STOP=1', '-c', sql], { stdio: ['ignore', 'pipe', 'pipe'] });
const pegar = (bd, archivo) => execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', bd, '-1', '-f', archivo], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
const sembrar = (bd, hoy) => execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', ...(hoy ? ['-v', 'hoy=' + hoy] : []), '-U', 'editor_sql', '-d', bd, '-f', path.join(__dirname, 'f16-semilla.sql'),
  ...(SEMILLA_NOM ? ['-f', SEMILLA_NOM] : [])], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
const psql = (bd, sql) => execFileSync('psql', ['-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', bd, '-f', '-'], { env: ENV, input: sql, stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 1 << 28 }).toString();
const dolar = s => { let t = 'q'; while (s.includes(`$${t}$`)) t += 'x'; return `$${t}$${s}$${t}$`; };
// Una orden como la pantalla por PostgREST: quien (dueno | equipo), su nivel y la consulta (devuelve un jsonb). Un error vuelve
// como {ERROR, message, detail, hint}. «previo»: lo que hace antes el SQL Editor en la misma transacción (con rollback no queda)
const AYUDA = `
create or replace function pg_temp.pedir(p_sql text, p_quien text, p_aal text) returns jsonb language plpgsql as $f$
declare v jsonb; uid text; c text; m text; d text; h text;
begin
  uid := case p_quien when 'dueno' then '${DUENO}' when 'equipo' then '${EQUIPO}' end;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', p_aal)::text, true);
  perform set_config('request.jwt.claim.sub', uid, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics c = returned_sqlstate, m = message_text, d = pg_exception_detail, h = pg_exception_hint;
    v := jsonb_build_object('ERROR', c, 'message', m, 'detail', nullif(d, ''), 'hint', nullif(h, ''));
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return v;
end $f$;`;
function pedir(bd, ordenes, previo = null) {
  const sql = ['begin;', AYUDA, ...(previo ? [previo] : []), ...ordenes.map(o => `select coalesce(pg_temp.pedir(${dolar(o.sql)}, '${o.quien || 'dueno'}', '${o.aal || 'aal2'}')::text, 'null');`), 'rollback;'].join('\n');
  const out = psql(bd, sql).split('\n').filter(l => l.length);
  if (out.length !== ordenes.length) throw new Error(`pedí ${ordenes.length} y contestó ${out.length}`);
  return out.map(l => JSON.parse(l));
}
// lo que PostgREST contesta a un error: el código, el mensaje y su estado HTTP (42501: 403)
const comoPostgrest = e => ({ status: e.ERROR === '42501' ? 403 : 400, error: { code: e.ERROR, message: e.message, details: e.detail || null, hint: e.hint || null } });
const tablero = p => ({ sql: `select fn_tablero(${dolar(JSON.stringify(p))}::jsonb)` });
const sano = (r, que) => { if (!r || r.ERROR || r.ok !== true) throw new Error(`${que}: fn_tablero no contestó bien: ${JSON.stringify(r).slice(0, 300)}`); return r; };

// ---------- 1. armar las cuatro bases (la de producción, sin semilla) ----------
for (const [bd, hoy, semilla] of [[BD, null, true], [BDM, HOY_M, true], [BDO, HOY_O, true], [BDP, null, false]]) {
  console.log(`armando ${bd} desde ${PLANTILLA}${hoy ? ` (hoy fingido: ${hoy})` : ''}${semilla ? '' : ' (sin semilla: producción al pegar c16)'}…`);
  su(`drop database if exists ${bd}`);
  su(`create database ${bd} template ${PLANTILLA} owner editor_sql`);
  su(`grant create on database ${bd} to editor_sql`);
  // (11c) las capas del árbol de la Fase 11c, como las pega Edgar encima de la lista v305
  for (const f of CAPAS) pegar(bd, path.join(ROOT, f));
  if (semilla) sembrar(bd, hoy);
  // (sin semilla, los nombres de las obras de 02-semilla.sql pasan a «ZZ» como los deja f16-semilla.sql: ningún número cambia)
  else psql(bd, `update proyectos set nombre = 'ZZ Casa Uno', cliente = 'ZZ Cliente Casa', direccion = '1 ZZ St, Ocala, FL' where id = 'casa-perez-k3m9';
update proyectos set nombre = 'ZZ Oficina Dos', cliente = 'ZZ Cliente Oficina', direccion = '2 ZZ Ave, Ocala, FL' where id = 'oficina-nch-7xq2';
update proyectos set nombre = 'ZZ Taller Tres', cliente = 'ZZ Cliente Taller', direccion = '3 ZZ Rd, Ocala, FL' where id = 'taller-ruiz-5b2n';`);
  pegar(bd, C16);
  console.log(semilla ? '  capas de la 11c, semilla y c16 puestas' : '  capas de la 11c y c16 puestas');
}

// ---------- 2. lo que la pantalla pide ----------
const TODAS = ['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar', 'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras', 'nomina'];
const PERIODOS = ['mes', 'mes_pasado', 'anio', 'anio_pasado'];
function escena(bd, nombre, op = {}) {
  // el tablero entero; la tarjeta de resultados con cada período del selector; la de ventas con el año anterior (el otro botón)
  const [todas, ...res] = pedir(bd, [tablero({}), ...PERIODOS.map(periodo => tablero({ tarjetas: ['resultados'], resultados: { periodo } }))]);
  sano(todas, nombre);
  if (JSON.stringify(todas.tarjetas) !== JSON.stringify(TODAS) || todas.sigue.length) throw new Error(`${nombre}: el tablero no trajo las ${TODAS.length} tarjetas de una vez (¿el c16 de la 11c, con la tarjeta de la nómina?): ${JSON.stringify(todas.tarjetas)}`);
  // (en producción sin semilla una tarjeta puede decir que no tiene nada: eso se captura tal cual; con la semilla, todas contestan)
  const malas = TODAS.filter(k => !todas[k] || (todas[k].ok !== true && !(op.produccion && todas[k].ok === false && !todas[k].codigo)));
  if (malas.length) throw new Error(`${nombre}: tarjetas que no contestan en el banco de pruebas: ${malas.map(k => `${k} (${todas[k] && todas[k].motivo})`).join(', ')}`);
  const anio = Number(todas.hoy.slice(0, 4)) - 1;
  const [va] = pedir(bd, [tablero({ tarjetas: ['ventas'], ventas: { anio } })]);
  return { todas, resultados: Object.fromEntries(PERIODOS.map((p, i) => [p, sano(res[i], `${nombre} resultados ${p}`).resultados])),
    ventas: { [anio]: sano(va, `${nombre} ventas ${anio}`).ventas } };
}
console.log('el tablero, hoy…');
const hoy = escena(BD, 'hoy');
console.log(`el tablero, el ${HOY_M}…`);
const marzo = escena(BDM, 'marzo');
console.log(`el tablero, el ${HOY_O} (el primer mes del año nuevo)…`);
const enero = escena(BDO, 'enero');
console.log('el tablero en producción, al pegar c16 (sin semilla)…');
const produccion = escena(BDP, 'produccion', { produccion: true });
if (produccion.todas.libro.apertura_en_el_libro !== false) throw new Error('producción: se esperaba el libro sin la apertura (así está producción hasta que Edgar la pegue)');

// el tope por reloj: con un tope corto alcanzan unas y las demás salen en «sigue»; la segunda llamada pide lo que siguió (sin tope que la corte)
console.log('el tope por reloj…');
// (un tope que deje unas sí y otras no: se prueban de menos a más hasta que alcancen unas cuantas)
let tope1 = null, topeMs = null;
for (const ms of [8, 15, 25, 40, 60, 90, 130]) {
  const [r] = pedir(BD, [tablero({ tope_ms: ms })]);
  sano(r, 'tope');
  if (r.sigue.length > 0 && r.sigue.length < TODAS.length) { tope1 = r; topeMs = ms; break; }
}
if (!tope1) throw new Error('ningún tope dejó unas tarjetas sí y otras no: no se puede probar «sigue»');
const [tope2] = pedir(BD, [tablero({ tarjetas: tope1.sigue })]);
sano(tope2, 'tope (segunda)');
if (tope2.sigue.length) throw new Error('la segunda llamada también dejó tarjetas para después');

// dos capas que no están (la base sin los préstamos de c6 ni los cobros en línea de p1) y una tarjeta que falla sola (el use tax,
// sin permiso de leer su vista): en transacciones que se deshacen
console.log('capas que no están y una tarjeta que falla…');
const [capas] = pedir(BD, [tablero({})], 'drop view v_prestamos cascade; drop view v_stripe_pagos cascade;');
sano(capas, 'capas');
if (capas.prestamos.ok !== false || capas.prestamos.falta !== 'c6' || capas.cobros_en_linea.ok !== false || capas.cobros_en_linea.falta !== 'p1')
  throw new Error(`sin préstamos ni Stripe, las tarjetas no lo dicen: ${JSON.stringify([capas.prestamos, capas.cobros_en_linea])}`);
const [falla] = pedir(BD, [tablero({})], 'revoke select on v_dr15_mes from authenticated;');
sano(falla, 'falla');
const fallan = TODAS.filter(k => falla[k].ok !== true);
if (fallan.join() !== 'use_tax' || falla.use_tax.codigo !== '42501') throw new Error(`la falla del use tax no salió sola: ${fallan.join()} ${JSON.stringify(falla.use_tax)}`);

// DOS ESCENAS APARTE, en transacciones que se deshacen:
// (a) un cobro de Stripe ya depositado (pi_ZZF16A de la semilla: su depósito llegó y está casado) que hoy se reembolsa en 250.00: p1
//     devuelve el cobro viejo y registra uno nuevo por 1,000.00; Stripe descontará los 250.00 del siguiente depósito
console.log('aparte: un cobro de Stripe depositado y reembolsado después…');
const ZZ_FOTO = `
create function pg_temp.zz_foto(p_pi text, p_estado text, p_centavos bigint, p_medio text, p_fecha date) returns jsonb language sql as $f$
  select jsonb_build_object(
    'pi', p_pi, 'visto_el', clock_timestamp(), 'estado', p_estado, 'monto', p_centavos,
    'recibido', case when p_estado = 'succeeded' then p_centavos else 0 end, 'moneda', 'usd', 'livemode', false,
    'creado', extract(epoch from now())::bigint,
    'metadata', (select jsonb_build_object('mxp', 'p1', 'enlace', e.id::text, 'factura_id', e.factura_id::text, 'factura', e.factura_num,
                                           'retencion', case when e.con_retencion then 'si' else 'no' end)
                   from stripe_enlaces e where e.plink = 'plink_' || substr(p_pi, 4)),
    'plink', 'plink_' || substr(p_pi, 4), 'sesion', 'cs_' || substr(p_pi, 4), 'sesion_completa', true, 'medio', p_medio,
    'cargo', 'ch_' || substr(p_pi, 4),
    'fecha_exito', case when p_estado = 'succeeded' then p_fecha::text end,
    'cargos', jsonb_build_array(jsonb_build_object('id', 'ch_' || substr(p_pi, 4), 'estado', 'succeeded', 'medio', p_medio, 'bt', 'txn_' || p_pi,
                'creado', extract(epoch from now())::bigint, 'monto', p_centavos)),
    'reembolsos', '[]'::jsonb, 'disputas', '[]'::jsonb, 'ultimo_error', null::jsonb)
$f$;
do $d$ begin
  perform fn_stripe_pago_sincronizar(
    pg_temp.zz_foto('pi_ZZF16A', 'succeeded', 125000, 'tarjeta', greatest(fn_fecha_miami(now()) - 8, date '2026-10-01'))
    || jsonb_build_object('reembolsos', jsonb_build_array(jsonb_build_object('id', 're_ZZX16', 'monto', 25000, 'estado', 'succeeded',
         'creado', extract(epoch from now())::bigint, 'bt', 'txn_re_ZZX16', 'bt_fallo', null, 'motivo_fallo', null))),
    'evt_ZZX16R');
end $d$;`;
const [reembolso] = pedir(BD, [tablero({ tarjetas: ['cobros', 'facturas', 'cobros_en_linea'] })], ZZ_FOTO);
sano(reembolso, 'reembolso');
if (!reembolso.cobros_en_linea.por_descontar || !(Number(reembolso.cobros.cobrado.devuelto.stripe.n) > 0))
  throw new Error('el reembolso no salió: ni «por descontar» en los cobros en línea ni lo devuelto por Stripe en el embudo: ' + JSON.stringify([reembolso.cobros_en_linea.por_descontar, reembolso.cobros.cobrado.devuelto]));
// (b) producción sin la apertura (como está hasta que Edgar la pegue): una renta de 1,850.00 pagada hoy desde el banco (1010) deja
//     la caja en rojo; sin la apertura eso no es un sobregiro de verdad: la tarjeta lo dice y no da la alarma
console.log('aparte: producción sin la apertura, con una renta pagada desde el banco…');
const RENTA = `
do $d$ begin
  perform set_config('request.jwt.claims', json_build_object('sub', '${DUENO}', 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', '${DUENO}', true);
  execute 'set local role authenticated';
  perform fn_postear(jsonb_build_object('fecha', fn_fecha_miami(now())::text, 'descripcion', 'ZZ PRUEBA: una renta pagada desde el banco (se deshace)',
            'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '1850.00'), jsonb_build_object('cuenta', '1010', 'monto', '-1850.00'))));
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $d$;`;
const [renta] = pedir(BDP, [tablero({})], RENTA);
sano(renta, 'renta');
if (!(renta.caja.ok === true && renta.caja.sin_apertura === true && Number(renta.caja.hoy.sobregiro) > 0 && renta.caja.hoy.alarma === false))
  throw new Error('producción con la renta: se esperaba la caja sin apertura, en rojo y sin alarma: ' + JSON.stringify(renta.caja && renta.caja.hoy));

// (c) el primer mes del libro: el 20-oct-2026 (el reloj de la base, vuelto a ese día dentro de la transacción: lo que el libro tiene
//     después es «de después de hoy»): la caja y las ventas con UN solo mes
console.log('aparte: el 20-oct-2026, el primer mes del libro…');
const PRIMER_MES = `
create or replace function public.fn_fecha_miami(t timestamptz) returns date language sql stable
  set search_path = public, pg_temp as $b$
    select case when t between now() - interval '6 hours' and now() + interval '6 hours'
                then least((t at time zone 'America/New_York')::date, date '2026-10-20')
                else (t at time zone 'America/New_York')::date end $b$;`;
const [primer_mes] = pedir(BD, [tablero({ tarjetas: ['caja', 'ventas'] })], PRIMER_MES);
sano(primer_mes, 'primer mes');
if (primer_mes.hoy !== '2026-10-20' || primer_mes.caja.meses_con_libro !== 1 || primer_mes.ventas.meses_con_libro !== 1)
  throw new Error('el primer mes del libro: se esperaba un solo mes en la caja y en las ventas: ' + JSON.stringify([primer_mes.hoy, primer_mes.caja.meses_con_libro, primer_mes.ventas.meses_con_libro]));

// (d) un cheque de hace 40 días (fuera de los 30 del embudo) aplicado a una factura de la semilla que rebota hace 5: lo cobrado en los
//     30 días no cambia y el rebote no está «ya restado» de nada: la base lo manda aparte (cobrado.devuelto_antes)
console.log('aparte: un cheque de hace 40 días que rebota hace 5…');
const DEVUELTO_ANTES = `
do $d$
declare v_f bigint; r jsonb; v_c uuid; v_hoy date := fn_fecha_miami(now());
begin
  select f.id into v_f from facturas f where f.num = 'ZZ-QB-902';
  r := fn_cobro_registrar(jsonb_build_object('fecha', (v_hoy - 40)::text, 'monto', '1000.00', 'cuenta', '1010', 'medio', 'cheque',
         'referencia', 'ZZ PRUEBA: un cheque de hace 40 días', 'duplicado_confirmado', 'ZZ PRUEBA: se deshace',
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', v_f, 'monto', '1000.00'))));
  v_c := coalesce((r ->> 'cobro')::uuid, (r ->> 'id')::uuid);
  perform fn_cobro_devolver(v_c, v_hoy - 5, 'ZZ PRUEBA: el cheque rebotó (se deshace)');
end $d$;`;
const [devuelto_antes] = pedir(BD, [tablero({ tarjetas: ['cobros', 'facturas'] })], DEVUELTO_ANTES);
sano(devuelto_antes, 'devuelto de antes');
if (!(devuelto_antes.cobros.cobrado.devuelto_antes && Number(devuelto_antes.cobros.cobrado.devuelto_antes.n) === 1 && Number(devuelto_antes.cobros.cobrado.devuelto_antes.monto) === 1000
      && Number(devuelto_antes.cobros.cobrado.monto) === Number(hoy.todas.cobros.cobrado.monto) && Number(devuelto_antes.cobros.cobrado.devuelto.monto) === Number(hoy.todas.cobros.cobrado.devuelto.monto)))
  throw new Error('el cheque de antes que rebota: se esperaba lo cobrado y lo devuelto «ya restado» como hoy, y los 1,000.00 aparte (devuelto_antes): ' + JSON.stringify(devuelto_antes.cobros.cobrado));

// (11c) LA NÓMINA (c15) EN EL TABLERO: la de la semilla (dos nóminas posteadas —la próxima con día de pago después de hoy—, cargos de
// Gusto casados y otros esperando); el tablero entero SIN el código del teléfono (aal1: lo de cada nómina, «con el código»); y, en
// transacciones que se deshacen, sin c15 (sus vistas quitadas), una nómina de UNA persona (un bono) posteada ayer y la misma importada
// sin postear, cada una con y sin el código
console.log('(11c) la nómina: con y sin el código, sin c15, una nómina de una persona y una sin postear…');
const nom = hoy.todas.nomina;
if (!(nom && nom.ok === true && nom.ultima && nom.ultima.con_codigo === true && nom.proxima && nom.proxima.dia_pago > hoy.todas.hoy && nom.meses.length > 0
      && Number(nom.cargos.n) > 0 && nom.atender.some(a => a.clave === 'cargos')))
  throw new Error('la nómina de la semilla no salió en el tablero (la última y la próxima con el código, los meses, los cargos que esperan): ' + JSON.stringify(nom).slice(0, 400));
if (!(hoy.todas.caja.proyeccion && hoy.todas.caja.proyeccion.meses.some(m => Number(m.nomina) > 0)))
  throw new Error('la proyección de la caja no resta lo que se debe de la nómina: ' + JSON.stringify(hoy.todas.caja.proyeccion && hoy.todas.caja.proyeccion.meses));
const [sin_codigo] = pedir(BD, [{ ...tablero({}), aal: 'aal1' }]);
sano(sin_codigo, 'sin el código');
if (!(sin_codigo.nomina.ok === true && sin_codigo.nomina.con_codigo === false && sin_codigo.nomina.codigo && sin_codigo.nomina.ultima.con_codigo === false
      && sin_codigo.nomina.ultima.costo === undefined && sin_codigo.nomina.por_postear == null))
  throw new Error('sin el código, la tarjeta de la nómina enseña lo de una nómina: ' + JSON.stringify(sin_codigo.nomina).slice(0, 400));
const SIN_C15 = 'drop view v_nomina_corridas cascade; drop view v_nomina_control cascade;';
const [sin_c15] = pedir(BD, [tablero({})], SIN_C15);
sano(sin_c15, 'sin c15');
if (!(sin_c15.nomina.ok === false && sin_c15.nomina.falta === 'c15' && sin_c15.capas.c15 === false && sin_c15.acciones.lista.some(x => x.clave === 'nomina' && x.disponible === false)))
  throw new Error('sin c15, la tarjeta y la acción de la nómina no lo dicen: ' + JSON.stringify([sin_c15.nomina, sin_c15.capas]));
// (el bono de UNA persona —ZZ Nomina Uno—, con día de pago ayer —o el día que se diga: hoy + «pago»—: bruto 400.00, retenido 70.60,
// neto 329.40; patrón 43.80)
const BONO = (postear, pago = -1) => `
do $d$
declare r jsonb; c uuid; hoy date := fn_fecha_miami(now()); csv text;
begin
  csv := 'Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Bonus,Gross earnings,'
         || 'Employee federal income tax,Employee social security tax,Employee medicare tax,Employee taxes,Net pay,Check amount,'
         || 'Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes' || E'\n'
         || format('ZZ Nomina,Uno,%s,%s,%s,Bonus,Direct Deposit,400.00,400.00,40.00,24.80,5.80,70.60,329.40,329.40,24.80,5.80,2.40,10.80,43.80',
                   to_char(hoy - 14, 'MM/DD/YYYY'), to_char(hoy - 1, 'MM/DD/YYYY'), to_char(hoy + (${pago}), 'MM/DD/YYYY')) || E'\n';
  r := fn_nomina_importar(jsonb_build_object('nombre', 'zz-f16-bono.csv', 'sha256', encode(sha256(convert_to(csv, 'UTF8')), 'hex'), 'bytes', octet_length(csv),
         'filas', (select jsonb_agg(to_jsonb(string_to_array(l, ',')) order by o) from unnest(string_to_array(rtrim(csv, E'\n'), E'\n')) with ordinality u(l, o))), '{}'::jsonb);
  c := (select (q ->> 'corrida')::uuid from jsonb_array_elements(r -> 'corridas') q where q ->> 'resultado' = 'nueva' limit 1);
  if c is null then raise exception 'el bono no entró: %', left(r::text, 300); end if;
  ${postear ? "perform fn_nomina_postear(c, fn_nomina_propuesta(c) ->> 'visto');" : ''}
end $d$;`;
const [una_c, una_s] = pedir(BD, [tablero({}), { ...tablero({}), aal: 'aal1' }], BONO(true));
sano(una_c, 'una persona'); sano(una_s, 'una persona sin el código');
if (!(Number(una_c.nomina.ultima.personas) === 1 && Number(una_c.nomina.ultima.bruto) === 400 && una_s.nomina.ultima.con_codigo === false && una_s.nomina.ultima.bruto === undefined))
  throw new Error('la nómina de una persona: ' + JSON.stringify([una_c.nomina.ultima, una_s.nomina.ultima]));
const [pp_c, pp_s] = pedir(BD, [tablero({}), { ...tablero({}), aal: 'aal1' }], BONO(false));
sano(pp_c, 'por postear'); sano(pp_s, 'por postear sin el código');
if (!(Number(pp_c.nomina.por_postear.n) === 1 && pp_c.nomina.atender.some(a => a.clave === 'por_postear') && pp_s.nomina.por_postear == null
      && pp_c.acciones.lista.find(x => x.clave === 'nomina').n === hoy.todas.acciones.lista.find(x => x.clave === 'nomina').n + 1))
  throw new Error('la nómina sin postear: ' + JSON.stringify([pp_c.nomina.por_postear, pp_s.nomina.por_postear]));

// (11c, con el c16 de verdad —marca 2026111402—) LO QUE SU CONTRATO TRAE Y EL PROTOTIPO NO, del banco y en transacciones que se deshacen:
// (e) EL CRITERIO «codigo» (fn_tablero_nomina_criterio cambiada dentro de la transacción, como la cambiaría Edgar al volver a pegar c16):
//     sin el código, ni la tarjeta de la nómina ni la de gastos ni la proyección de la caja escriben el dinero de la nómina; con el
//     código, lo mismo que con «libro»
console.log('(11c) el criterio «codigo», la cuenta de reembolsos al revés, la próxima importada y un cargo des-casado…');
const CRITERIO = `create or replace function public.fn_tablero_nomina_criterio() returns text language sql stable
  set search_path = public, pg_temp as $c$ select 'codigo'::text $c$;`;
const [crit_s, crit_c] = pedir(BD, [{ ...tablero({}), aal: 'aal1' }, tablero({})], CRITERIO);
sano(crit_s, 'criterio «codigo» sin el código'); sano(crit_c, 'criterio «codigo» con el código');
if (!(crit_s.nomina.ok === true && crit_s.nomina.criterio === 'codigo' && crit_s.nomina.a_la_vista === false && crit_s.nomina.meses.every(m => m.costo == null)
      && crit_s.nomina.debe.a_la_vista === false && crit_s.nomina.debe.monto === undefined && crit_s.nomina.cargos.monto === undefined && crit_s.nomina.bolsa.monto == null
      && crit_s.gastos.tapado && crit_s.gastos.tapado.cuentas.length > 0 && crit_s.caja.proyeccion.nomina_a_la_vista === false && crit_s.caja.proyeccion.meses.every(m => m.nomina == null)))
  throw new Error('el criterio «codigo» sin el código: la tarjeta, gastos o la caja enseñan el dinero de la nómina: ' + JSON.stringify([crit_s.nomina.a_la_vista, crit_s.nomina.debe, crit_s.gastos.tapado, crit_s.caja.proyeccion && crit_s.caja.proyeccion.nomina_a_la_vista]).slice(0, 400));
{ const sinMs = x => { const c = { ...x }; delete c.ms; delete c.criterio; return JSON.stringify(c); };
  if (!(crit_c.nomina.a_la_vista === true && sinMs(crit_c.nomina) === sinMs(hoy.todas.nomina) && sinMs(crit_c.gastos) === sinMs(hoy.todas.gastos) && sinMs(crit_c.caja) === sinMs(hoy.todas.caja)))
    throw new Error('el criterio «codigo» CON el código no da lo mismo que «libro» (la nómina, gastos y la caja)'); }
// (f) LA CUENTA DE REEMBOLSOS A EMPLEADOS AL REVÉS: una de las dos compras que el oficial pagó de su bolsillo sale del libro (un asiento
//     al revés del SQL Editor): la nómina ya se la reembolsó, así que esa cuenta queda debiendo a favor (58.40); no baja lo que se debe
//     (va «aparte», con su texto) y el Balance dice 58.40 menos
const APARTE = `do $d$ begin perform fn_postear(jsonb_build_object('fecha', fn_fecha_miami(now())::text,
  'descripcion', 'ZZ PRUEBA: la compra del oficial sale del libro (se deshace)',
  'lineas', jsonb_build_array(jsonb_build_object('cuenta', '2250', 'monto', '58.40', 'tercero_tipo', 'empleado',
                                                 'tercero_id', (select p.id::text from perfiles p where p.nombre = 'ZZ Oficial Tres')),
                              jsonb_build_object('cuenta', '5100', 'monto', '-58.40', 'proyecto_id', 'zz-nave-cuatro-a1b2')))); end $d$;`;
const [aparte] = pedir(BD, [tablero({})], APARTE);
sano(aparte, 'reembolsos al revés');
if (!(aparte.nomina.debe.aparte && Number(aparte.nomina.debe.aparte.monto) === 58.4 && Number(aparte.nomina.debe.monto) === Number(hoy.todas.nomina.debe.monto)
      && Number(aparte.nomina.debe.libro) === Number((Number(hoy.todas.nomina.debe.libro) - 58.4).toFixed(2))))
  throw new Error('la cuenta de reembolsos al revés: se esperaba «aparte» con 58.40 y lo que se debe igual que hoy: ' + JSON.stringify(aparte.nomina.debe).slice(0, 400));
// (f2) (los arreglos de la verificación, c16 marca 2026111403) UNAS VACACIONES DEVENGADAS A MANO: 400.00 en la 2215, que está en el renglón
//     «nómina por pagar» del Balance y ninguna nómina paga. Lo que se debe de la nómina, cuándo sale y lo que la proyección resta cada mes
//     NO cambian; van aparte («otras», con su texto), el Balance dice 400.00 más y la caja las deja en lo que no incluye, con su nombre
const OTRAS = `do $d$ begin perform fn_postear(jsonb_build_object('fecha', fn_fecha_miami(now())::text,
  'descripcion', 'ZZ PRUEBA: unas vacaciones devengadas a mano (se deshace)',
  'lineas', jsonb_build_array(jsonb_build_object('cuenta', '6100', 'monto', '400.00'), jsonb_build_object('cuenta', '2215', 'monto', '-400.00')))); end $d$;`;
const [otras] = pedir(BD, [tablero({})], OTRAS);
sano(otras, 'las vacaciones devengadas');
{ const o = otras.nomina.debe, h = hoy.todas.nomina.debe, ni = x => ((x.caja.proyeccion || {}).no_incluye || []).find(s => s.clave === 'deuda' && s.linea === 'nomina_por_pagar');
  if (!(o.otras && Number(o.otras.monto) === 400 && o.otras.cuentas.length === 1 && o.otras.cuentas[0].cuenta === '2215' && /no va en lo que se debe de la nómina/.test(o.otras.texto)
        && h.otras == null && Number(o.monto) === Number(h.monto) && JSON.stringify(o.pagos) === JSON.stringify(h.pagos) && JSON.stringify(o.cuentas) === JSON.stringify(h.cuentas)
        && Number(o.libro) === Number((Number(h.libro) + 400).toFixed(2))
        && JSON.stringify(otras.caja.proyeccion.meses.map(m => m.nomina)) === JSON.stringify(hoy.todas.caja.proyeccion.meses.map(m => m.nomina))
        && ni(otras) && Number(ni(otras).monto) === 400 && JSON.stringify(ni(otras).cuentas) === '["2215"]' && !ni(hoy.todas)))
    throw new Error('las vacaciones devengadas: se esperaban aparte («otras», 400.00 en la 2215), lo que se debe de la nómina y cuándo sale igual que hoy, y en lo que la caja no incluye: ' + JSON.stringify([o, ni(otras)]).slice(0, 600)); }
// (g) LA PRÓXIMA, IMPORTADA Y SIN POSTEAR: el bono con día de pago mañana (antes que la B, que es dentro de 3 días): con el código, la
//     próxima es esa (importada: sin «por pagar» ni asiento); sin el código, la del libro (la B)
const [pxi_c, pxi_s] = pedir(BD, [tablero({}), { ...tablero({}), aal: 'aal1' }], BONO(false, 1));
sano(pxi_c, 'próxima importada'); sano(pxi_s, 'próxima importada sin el código');
if (!(pxi_c.nomina.proxima && pxi_c.nomina.proxima.estado === 'importada' && pxi_c.nomina.proxima.por_pagar == null && pxi_c.nomina.proxima.asiento == null
      && Number(pxi_c.nomina.proxima.personas) === 1 && pxi_s.nomina.proxima.con_codigo === false && pxi_s.nomina.proxima.dia_pago === hoy.todas.nomina.proxima.dia_pago))
  throw new Error('la próxima importada: ' + JSON.stringify([pxi_c.nomina.proxima, pxi_s.nomina.proxima]).slice(0, 400));
// (h) UN CARGO DE GUSTO DES-CASADO EN LA BANDEJA (el de los impuestos de la nómina A, que se casó en Nómina): c15 lo cuenta como
//     des-casado (con el código), su cuadre 25 sale en rojo y el cargo vuelve a esperar: la tarjeta, la acción y «Qué atender» lo dicen
const DESCASAR = `do $d$ begin
  perform set_config('request.jwt.claims', json_build_object('sub', '${DUENO}', 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', '${DUENO}', true);
  execute 'set local role authenticated';
  perform fn_banco_descasar((select id from movimientos_banco where id_externo = 'zz-gusto-tax'), 'ZZ PRUEBA: se des-casa en la Bandeja (se deshace)');
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $d$;`;
const [desc_c, desc_s] = pedir(BD, [tablero({}), { ...tablero({}), aal: 'aal1' }], DESCASAR);
sano(desc_c, 'des-casado'); sano(desc_s, 'des-casado sin el código');
if (!(Number(desc_c.nomina.cargos.descasados) === 1 && Number(desc_c.nomina.control.cuadres_rojos) > 0 && desc_c.nomina.atender.some(a => a.clave === 'cuadre')
      && desc_c.acciones.lista.find(x => x.clave === 'nomina').alarma === true && desc_s.nomina.cargos.descasados == null && !desc_s.nomina.atender.some(a => a.clave === 'cuadre')))
  throw new Error('el cargo des-casado: ' + JSON.stringify([desc_c.nomina.cargos, desc_c.nomina.control, desc_s.nomina.cargos]).slice(0, 400));

// los errores que la pantalla enseña
console.log('errores…');
const [equipo, clave] = pedir(BD, [{ ...tablero({}), quien: 'equipo' }, tablero({ tarjetas: ['millas'] })]);
if (!equipo.ERROR || equipo.ERROR !== '42501') throw new Error('el equipo no recibió 42501: ' + JSON.stringify(equipo));
if (!clave.ERROR || clave.ERROR !== '22023') throw new Error('una tarjeta que no existe no dio 22023: ' + JSON.stringify(clave));

// ---------- 3. pedir unas sueltas da lo mismo que el tablero entero (salvo «ms») ----------
console.log('las tarjetas sueltas…');
const sinMs = x => { const c = { ...x }; delete c.ms; return JSON.stringify(c); };
const sueltas = [['gastos', 'prestamos'], ['caja'], ['resultados', 'por_pagar', 'obras'], TODAS.filter(k => k !== 'gastos' && k !== 'ventas')];
const rs = pedir(BD, sueltas.map(t => tablero({ tarjetas: t })));
const distintas = [];
sueltas.forEach((t, i) => { sano(rs[i], 'sueltas'); for (const k of t) if (sinMs(rs[i][k]) !== sinMs(hoy.todas[k])) distintas.push(`${k} (pedida con ${t.join('+')})`); });
if (distintas.length) throw new Error('pedir unas sueltas NO da lo mismo que el tablero entero: ' + distintas.join(', '));

// ---------- 4. nada de nombres de la semilla de siempre: solo «ZZ» (sin distinguir mayúsculas) ----------
// Los ids de obra (proyecto_id, y el «sel» de su enlace) son slugs de pruebas/conta/02-semilla.sql, que ya es pública: no son
// nombres que se lean en la pantalla. Se comprueba que cada uno esté en 02-semilla.sql (o sea un id «zz-…» de f16-semilla.sql)
// y se quitan; en lo demás, ningún nombre de la semilla de siempre, ni en minúsculas.
const SEMILLA02 = fs.readFileSync(path.join(__dirname, '02-semilla.sql'), 'utf8'), SEMILLA16 = fs.readFileSync(path.join(__dirname, 'f16-semilla.sql'), 'utf8');
const ids = new Set(), noEsId = [];
const todo = JSON.stringify({ hoy, marzo, enero, produccion, tope1, tope2, capas, falla, reembolso, renta, primer_mes, devuelto_antes, sin_codigo, sin_c15, una_c, una_s, pp_c, pp_s,
  crit_s, aparte, otras, pxi_c, pxi_s, desc_c, desc_s }, (k, v) => {
  if ((k === 'sel' || k === 'proyecto_id') && typeof v === 'string') {
    if (SEMILLA02.includes(`'${v}'`) || (/^zz-/.test(v) && SEMILLA16.includes(`'${v}'`))) { ids.add(v); return '«id»'; }
    noEsId.push(v);
  }
  return v;
});
if (noEsId.length) throw new Error(`ids de obra que no son de 02-semilla.sql ni de f16-semilla.sql: ${[...new Set(noEsId)].join(', ')}`);
const bajo = todo.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
for (const malo of ['perez', 'luis', 'ruiz', 'nch']) { const m = bajo.match(new RegExp(`.{0,30}\\b${malo}\\b.{0,30}`)); if (m) throw new Error(`salió «${malo}» en lo capturado («${m[0]}»): la semilla debe dejarlo en «ZZ»`); }

// ---------- 5. escribir ----------
const salida = {
  _leeme: 'La base simulada del tablero de la portada «Resumen» (c16) que usa pantalla.js: lo que contestó el banco a fn_tablero. La genera pruebas/conta/f16-capturar.js; no se edita a mano. Datos inventados (ZZ).',
  capturado: { el: new Date().toISOString(), hoy: hoy.todas.hoy, hoy_marzo: marzo.todas.hoy, hoy_enero: enero.todas.hoy, plantilla: PLANTILLA, c16: huella(C16), semilla: huella('pruebas/conta/f16-semilla.sql'), version: hoy.todas.version,
    // (11c) las capas de la Fase 11c pegadas encima de la plantilla (su huella), la semilla de la nómina si vino aparte, y si el c16 no era el del árbol
    capas: Object.fromEntries(CAPAS.map(f => [f, huella(f)])), semilla_nomina: SEMILLA_NOM ? huella(SEMILLA_NOM) : null,
    c16_del_arbol: C16 === path.join(ROOT, 'docs/conta/c16-tablero.sql'),
    criterio_codigo_con_codigo: 'con el criterio «codigo» y CON el código, la tarjeta de la nómina, gastos y la caja dan lo mismo que con «libro» (salvo «ms» y «criterio»): comprobado',
    sueltas_igual: 'pedir unas tarjetas sueltas da lo mismo que esas tarjetas en el tablero entero, salvo «ms» (comprobado con ' + sueltas.map(t => t.join('+')).join(' · ') + ')',
    ids_de_obra: `los ids de obra que salen (${[...ids].sort().join(', ')}) son de 02-semilla.sql o de f16-semilla.sql; ningún nombre de la semilla de siempre, sin distinguir mayúsculas` },
  hoy, marzo, enero, produccion,
  tope: { tope_ms: topeMs, primera: tope1, segunda: tope2 },
  capas, falla,
  aparte: { reembolso, renta, primer_mes, devuelto_antes },
  // (11c) la nómina: el tablero entero sin el código; sin c15; una nómina de una persona y una sin postear, con y sin el código
  sin_codigo, nomina: { sin_c15, una_persona: { codigo: una_c, sin_codigo: una_s }, por_postear: { codigo: pp_c, sin_codigo: pp_s },
    // ((11c, el c16 de verdad) el criterio «codigo» sin el código —con él da lo mismo que «libro»: comprobado—; la cuenta de reembolsos al
    // revés; la próxima importada sin postear; un cargo de Gusto des-casado en la Bandeja —con y sin el código—; y (los arreglos de la
    // verificación) unas vacaciones devengadas, que no son de la nómina: «otras»)
    criterio_codigo: crit_s, aparte, otras, proxima_importada: { codigo: pxi_c, sin_codigo: pxi_s }, descasado: { codigo: desc_c, sin_codigo: desc_s } },
  errores: { equipo: comoPostgrest(equipo), tarjeta_mala: comoPostgrest(clave) }
};
fs.writeFileSync(SALIDA, JSON.stringify(salida) + '\n');
console.log(`listo: ${path.relative(ROOT, SALIDA)} (${(fs.statSync(SALIDA).size / 1024).toFixed(0)} KB; hoy ${salida.capturado.hoy}, marzo ${salida.capturado.hoy_marzo}, enero ${salida.capturado.hoy_enero}; con un tope de ${topeMs} ms siguieron ${tope1.sigue.length} de ${TODAS.length})`);
console.log(`(quedan ${BD}, ${BDM}, ${BDO} y ${BDP}: se borran a mano)`);
