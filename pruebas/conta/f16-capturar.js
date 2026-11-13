/* f16-capturar.js — LA BASE SIMULADA del tablero de la portada «Resumen» de
   Contabilidad (c16) de pruebas/conta/pantalla.js, SACADA DEL BANCO.

   No hay una mentira escrita a mano para el tablero: cada respuesta de
   fn_tablero que la pantalla recibe en pantalla.js es la que dio el banco
   (Postgres 17 en 127.0.0.1:5433) a la misma llamada, como el dueño
   (authenticated, aal2). Este script:
     1. arma <bd> (BORRA la que haya con ese nombre): un clon de la plantilla
        (de fábrica g12a: producción como queda con lo del 12-nov) con
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
        solo mes, la cifra sola);
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

   Uso (solo el banco; nada de red):
     node pruebas/conta/f16-capturar.js <bd> [plantilla=g12a]
   Tarda unos 25 s. Las cuatro bases quedan; se borran a mano:
     runuser -u postgres -- psql -X -h /var/run/postgresql -p 5433 -c "drop database <bd>" (y <bd>_m, <bd>_o y <bd>_p). */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { execFileSync } = require('child_process');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--'));
const BD = ARGS[0], PLANTILLA = ARGS[1] || 'g12a', BDM = BD + '_m', HOY_M = '2027-03-10', BDO = BD + '_o', HOY_O = '2027-01-20', BDP = BD + '_p';
const SAGRADAS = ['g12a', 'g10a', 'g9a', 'g8a', 'f9fix', 'p1fab', 'c9perf', PLANTILLA];
if (!BD || !/^[a-z][a-z0-9_]*$/.test(BD) || [BD, BDM, BDO, BDP].some(x => SAGRADAS.includes(x))) {
  console.error('uso: node pruebas/conta/f16-capturar.js <bd nueva> [plantilla=g12a]   (nunca una plantilla)'); process.exit(2);
}
const ROOT = path.resolve(__dirname, '..', '..');
const SALIDA = path.join(__dirname, 'pantalla-f16.json');
const ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT: '5433', PGPASSWORD: 'editor_sql' };
const DUENO = '00000000-0000-4000-a000-000000000001', EQUIPO = '00000000-0000-4000-a000-000000000002';
const huella = f => crypto.createHash('sha1').update(fs.readFileSync(path.join(ROOT, f))).digest('hex').slice(0, 12);

// ---------- el banco ----------
const su = sql => execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', '5433', '-v', 'ON_ERROR_STOP=1', '-c', sql], { stdio: ['ignore', 'pipe', 'pipe'] });
const pegar = (bd, archivo) => execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', bd, '-1', '-f', archivo], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
const sembrar = (bd, hoy) => execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', ...(hoy ? ['-v', 'hoy=' + hoy] : []), '-U', 'editor_sql', '-d', bd, '-f', path.join(__dirname, 'f16-semilla.sql')], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
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
  if (semilla) sembrar(bd, hoy);
  // (sin semilla, los nombres de las obras de 02-semilla.sql pasan a «ZZ» como los deja f16-semilla.sql: ningún número cambia)
  else psql(bd, `update proyectos set nombre = 'ZZ Casa Uno', cliente = 'ZZ Cliente Casa', direccion = '1 ZZ St, Ocala, FL' where id = 'casa-perez-k3m9';
update proyectos set nombre = 'ZZ Oficina Dos', cliente = 'ZZ Cliente Oficina', direccion = '2 ZZ Ave, Ocala, FL' where id = 'oficina-nch-7xq2';
update proyectos set nombre = 'ZZ Taller Tres', cliente = 'ZZ Cliente Taller', direccion = '3 ZZ Rd, Ocala, FL' where id = 'taller-ruiz-5b2n';`);
  pegar(bd, path.join(ROOT, 'docs/conta/c16-tablero.sql'));
  console.log(semilla ? '  semilla y c16 puestas' : '  c16 puesta');
}

// ---------- 2. lo que la pantalla pide ----------
const TODAS = ['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar', 'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras'];
const PERIODOS = ['mes', 'mes_pasado', 'anio', 'anio_pasado'];
function escena(bd, nombre, op = {}) {
  // el tablero entero; la tarjeta de resultados con cada período del selector; la de ventas con el año anterior (el otro botón)
  const [todas, ...res] = pedir(bd, [tablero({}), ...PERIODOS.map(periodo => tablero({ tarjetas: ['resultados'], resultados: { periodo } }))]);
  sano(todas, nombre);
  if (JSON.stringify(todas.tarjetas) !== JSON.stringify(TODAS) || todas.sigue.length) throw new Error(`${nombre}: el tablero no trajo las 15 tarjetas de una vez`);
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
  if (r.sigue.length > 0 && r.sigue.length < 15) { tope1 = r; topeMs = ms; break; }
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
const todo = JSON.stringify({ hoy, marzo, enero, produccion, tope1, tope2, capas, falla, reembolso, renta, primer_mes }, (k, v) => {
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
  capturado: { el: new Date().toISOString(), hoy: hoy.todas.hoy, hoy_marzo: marzo.todas.hoy, hoy_enero: enero.todas.hoy, plantilla: PLANTILLA, c16: huella('docs/conta/c16-tablero.sql'), semilla: huella('pruebas/conta/f16-semilla.sql'), version: hoy.todas.version,
    sueltas_igual: 'pedir unas tarjetas sueltas da lo mismo que esas tarjetas en el tablero entero, salvo «ms» (comprobado con ' + sueltas.map(t => t.join('+')).join(' · ') + ')',
    ids_de_obra: `los ids de obra que salen (${[...ids].sort().join(', ')}) son de 02-semilla.sql o de f16-semilla.sql; ningún nombre de la semilla de siempre, sin distinguir mayúsculas` },
  hoy, marzo, enero, produccion,
  tope: { tope_ms: topeMs, primera: tope1, segunda: tope2 },
  capas, falla,
  aparte: { reembolso, renta, primer_mes },
  errores: { equipo: comoPostgrest(equipo), tarjeta_mala: comoPostgrest(clave) }
};
fs.writeFileSync(SALIDA, JSON.stringify(salida) + '\n');
console.log(`listo: ${path.relative(ROOT, SALIDA)} (${(fs.statSync(SALIDA).size / 1024).toFixed(0)} KB; hoy ${salida.capturado.hoy}, marzo ${salida.capturado.hoy_marzo}, enero ${salida.capturado.hoy_enero}; con un tope de ${topeMs} ms siguieron ${tope1.sigue.length} de 15)`);
console.log(`(quedan ${BD}, ${BDM}, ${BDO} y ${BDP}: se borran a mano)`);
