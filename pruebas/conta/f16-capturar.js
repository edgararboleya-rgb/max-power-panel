/* f16-capturar.js — LA BASE SIMULADA del tablero de la portada «Resumen» de
   Contabilidad (c16) de pruebas/conta/pantalla.js, SACADA DEL BANCO.

   No hay una mentira escrita a mano para el tablero: cada respuesta de
   fn_tablero que la pantalla recibe en pantalla.js es la que dio el banco
   (Postgres 17 en 127.0.0.1:5433) a la misma llamada, como el dueño
   (authenticated, aal2). Este script:
     1. arma <bd> (BORRA la que haya con ese nombre): un clon de la plantilla
        (de fábrica g12a: producción como queda con lo del 12-nov) con
        f16-semilla.sql (un libro en uso de la apertura al 30-sep a HOY,
        inventado) y c16-tablero.sql; y <bd>_m, igual pero con «hoy» fingido
        en el 10-mar-2027 (la semilla lo sabe hacer: -v hoy=…), para ver las
        gráficas con varios meses de libro;
     2. le pide a fn_tablero, como el dueño, lo que la pantalla pide: el
        tablero entero; la tarjeta de resultados con cada período del
        selector (este mes, el mes pasado, el año); el tablero con un tope
        por reloj corto (lo que no alcanzó sale en «sigue») y la segunda
        llamada con lo que siguió; y, en transacciones que se deshacen, el
        tablero con dos capas que no están (sin los préstamos de c6 ni los
        cobros en línea de p1) y con una tarjeta que falla sola (el use tax,
        sin permiso de leer su vista: 42501); más los errores (el equipo,
        42501; una tarjeta que no existe, 22023);
     3. comprueba que pedir unas tarjetas sueltas da lo mismo que esas
        tarjetas en el tablero entero (salvo «ms»): así la pantalla.js puede
        contestar a «Personalizar» (pide solo las que se ven) con el tablero
        entero, y lo dice en el JSON;
     4. escribe pruebas/conta/pantalla-f16.json.
   Los números son los del banco el día en que se capturó (lo que depende de
   «hoy» es de ese día): la pantalla los enseña tal cual. Si c16 o la semilla
   cambian, se vuelve a correr y pantalla.js sigue con lo nuevo (comprueba la
   huella de los dos archivos).

   Uso (solo el banco; nada de red):
     node pruebas/conta/f16-capturar.js <bd> [plantilla=g12a]
   Tarda unos 20 s. Las dos bases quedan; se borran a mano:
     runuser -u postgres -- psql -X -h /var/run/postgresql -p 5433 -c "drop database <bd>" (y <bd>_m). */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { execFileSync } = require('child_process');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--'));
const BD = ARGS[0], PLANTILLA = ARGS[1] || 'g12a', BDM = BD + '_m', HOY_M = '2027-03-10';
const SAGRADAS = ['g12a', 'g10a', 'g9a', 'g8a', 'f9fix', 'p1fab', 'c9perf', PLANTILLA];
if (!BD || !/^[a-z][a-z0-9_]*$/.test(BD) || SAGRADAS.includes(BD) || SAGRADAS.includes(BDM)) {
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

// ---------- 1. armar las dos bases ----------
for (const [bd, hoy] of [[BD, null], [BDM, HOY_M]]) {
  console.log(`armando ${bd} desde ${PLANTILLA}${hoy ? ` (hoy fingido: ${hoy})` : ''}…`);
  su(`drop database if exists ${bd}`);
  su(`create database ${bd} template ${PLANTILLA} owner editor_sql`);
  su(`grant create on database ${bd} to editor_sql`);
  sembrar(bd, hoy);
  pegar(bd, path.join(ROOT, 'docs/conta/c16-tablero.sql'));
  console.log('  semilla y c16 puestas');
}

// ---------- 2. lo que la pantalla pide ----------
const TODAS = ['acciones', 'cobros', 'bancos', 'resultados', 'gastos', 'caja', 'facturas', 'ventas', 'por_cobrar', 'por_pagar', 'conexiones', 'cobros_en_linea', 'use_tax', 'prestamos', 'obras'];
const PERIODOS = ['mes', 'mes_pasado', 'anio'];
function escena(bd, nombre) {
  const [todas, ...res] = pedir(bd, [tablero({}), ...PERIODOS.map(periodo => tablero({ tarjetas: ['resultados'], resultados: { periodo } }))]);
  sano(todas, nombre);
  if (JSON.stringify(todas.tarjetas) !== JSON.stringify(TODAS) || todas.sigue.length) throw new Error(`${nombre}: el tablero no trajo las 15 tarjetas de una vez`);
  const malas = TODAS.filter(k => !todas[k] || todas[k].ok !== true);
  if (malas.length) throw new Error(`${nombre}: tarjetas que no contestan en el banco de pruebas: ${malas.map(k => `${k} (${todas[k] && todas[k].motivo})`).join(', ')}`);
  return { todas, resultados: Object.fromEntries(PERIODOS.map((p, i) => [p, sano(res[i], `${nombre} resultados ${p}`).resultados])) };
}
console.log('el tablero, hoy…');
const hoy = escena(BD, 'hoy');
console.log(`el tablero, el ${HOY_M}…`);
const marzo = escena(BDM, 'marzo');

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

// ---------- 4. nada de nombres de la semilla de siempre: solo «ZZ» ----------
const todo = JSON.stringify({ hoy, marzo, tope1, tope2, capas, falla });
for (const malo of ['Pérez', 'Perez', 'Luis', 'Ruiz', 'NCH']) if (todo.includes(malo)) throw new Error(`salió «${malo}» en lo capturado: la semilla debe dejarlo en «ZZ»`);

// ---------- 5. escribir ----------
const salida = {
  _leeme: 'La base simulada del tablero de la portada «Resumen» (c16) que usa pantalla.js: lo que contestó el banco a fn_tablero. La genera pruebas/conta/f16-capturar.js; no se edita a mano. Datos inventados (ZZ).',
  capturado: { el: new Date().toISOString(), hoy: hoy.todas.hoy, hoy_marzo: marzo.todas.hoy, plantilla: PLANTILLA, c16: huella('docs/conta/c16-tablero.sql'), semilla: huella('pruebas/conta/f16-semilla.sql'), version: hoy.todas.version,
    sueltas_igual: 'pedir unas tarjetas sueltas da lo mismo que esas tarjetas en el tablero entero, salvo «ms» (comprobado con ' + sueltas.map(t => t.join('+')).join(' · ') + ')' },
  hoy, marzo,
  tope: { tope_ms: topeMs, primera: tope1, segunda: tope2 },
  capas, falla,
  errores: { equipo: comoPostgrest(equipo), tarjeta_mala: comoPostgrest(clave) }
};
fs.writeFileSync(SALIDA, JSON.stringify(salida) + '\n');
console.log(`listo: ${path.relative(ROOT, SALIDA)} (${(fs.statSync(SALIDA).size / 1024).toFixed(0)} KB; hoy ${salida.capturado.hoy}, marzo ${salida.capturado.hoy_marzo}; con un tope de ${topeMs} ms siguieron ${tope1.sigue.length} de 15)`);
