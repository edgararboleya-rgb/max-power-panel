/* stripe-e2e.mjs — la función de borde `stripe` (p1) de punta a punta, sin
   internet: un Stripe simulado (stripe-simulado.mjs), la función contra el
   banco de pruebas (c1..c7 + s1 + p1-stripe.sql) y las comprobaciones de lo
   que pasa en la base: quién puede llamar (dueño en aal2; sin aal2, el
   equipo, sin sesión, la rutina con otro secreto), crear el enlace de pago
   (y Stripe caído, y un permiso que falta), la firma de los avisos (mala,
   vieja, del futuro, cuerpo alterado, dos v1), tarjeta con avisos repetidos
   y desordenados, ACH en camino → liquidado, ACH fallido, reembolso
   parcial, disputa (retiro y reintegro), el depósito con varios cobros y
   comisiones (composición en páginas) y el de Chase que trae Plaid
   (fn_banco_importar_filas, origen plaid) casando SOLO con su asiento, el
   aviso perdido, el barrido de la rutina, Stripe y la base caídos, la
   concurrencia, el depósito que falla, lo que Edgar resuelve, las acciones
   de la pantalla, la llave de prueba en una base que no la acepta, y el
   cierre: la 1020 y la 1140 en cero, fn_verificar_cadena, fn_banco_control y
   fn_estados_control en verde, ninguna fn_stripe_* en la API, y ninguna
   llave en ninguna parte.

   DOS MODOS: con Deno (DENO o /opt/node22/bin/deno) la función corre como en
   Supabase, en su puerto (8893), con npm:postgres contra la base; sin Deno
   (MODO NODE) se importa supabase/functions/stripe/index.ts en este proceso
   (Node 22 quita los tipos) y la base es psql (usarBaseDePruebas, solo con
   MXP_BANCO_PRUEBAS=1). Lo que se prueba es el mismo atender().

   Uso: node pruebas/conta/stripe-e2e.mjs [bd=p1stripe] [puerto_pg=5433]
        CONSERVAR=1 deja la base; SIN_CONSTRUIR=1 usa una que ya existe y
        está como la deja la construcción de aquí (p1 pegado, las facturas
        1101..1113 en el libro y sin pagos: p. ej. una copia hecha con
        «create database X template …» justo después de construir); SIN_DENO=1
        fuerza el modo node. Necesita el banco levantado (pruebas/conta/pg17.sh). */
import { spawn, execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import { firmar, firmarConFalsa } from './stripe-simulado.mjs';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const R = path.resolve(AQUI, '../..');
const D = path.join(R, 'docs/conta');
const BD = process.argv[2] || 'p1stripe';
const PGPORT = process.argv[3] || process.env.PGPORT || '5433';
const PG_ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT, PGPASSWORD: 'editor_sql' };
const DENO = process.env.DENO || '/opt/node22/bin/deno';
const CON_DENO = !process.env.SIN_DENO && existsSync(DENO);
const P_SIM = 8892, P_FN = 8893, P_FN2 = 8894, P_MUERTO = '5499';
const LLAVE = 'rk_test_prueba', WHSEC = 'whsec_prueba';
const HOY = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

const t0 = Date.now();
const log = (m) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
const resultados = [];
const respuestas = []; // todo lo que contestó la función (para buscar llaves al final)
function ok(nombre, cond, detalle) {
  resultados.push({ nombre, ok: !!cond });
  console.log(`${cond ? ' ok ' : 'MAL '} ${nombre}${cond ? '' : ' — ' + String(typeof detalle === 'string' ? detalle : JSON.stringify(detalle ?? '')).slice(0, 900)}`);
}
function q(sql) {
  return execFileSync('psql', ['-X', '-At', '-F', '|', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-c', sql], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'] }).toString().trim();
}
function qErr(sql) { try { return q(sql); } catch (e) { return 'error: ' + String(e.stderr || e.message).trim(); } }
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;
// psql asíncrono (para las llamadas a la vez)
function psqlAsync(sql, puerto = PGPORT) {
  return new Promise((res) => {
    const h = spawn('psql', ['-X', '-At', '-q', '-h', '127.0.0.1', '-p', puerto, '-U', 'editor_sql', '-d', BD, '-f', '-'], { env: PG_ENV });
    let salida = '', error = '';
    h.stdout.on('data', (d) => { salida += d; });
    h.stderr.on('data', (d) => { error += d; });
    h.on('close', (codigo) => res({ codigo, salida, error }));
    h.stdin.end(sql);
  });
}

// ---- 1. la base ----------------------------------------------------------
function psqlArchivo(archivo, extra = []) {
  return execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-f', archivo, ...extra], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20 }).toString();
}
let pruebasP1 = null;
if (!process.env.SIN_CONSTRUIR) {
  log(`construyo ${BD} en el puerto ${PGPORT} (c1..c7, s1 y p1: unos segundos)…`);
  const archivos = ['03-storage-simulacro.sql', ...['c1-plan-de-cuentas', 'c2-libro', 'c3-puentes', 'c4-estados', 'c6-banco'].map((f) => `../../docs/conta/${f}.sql`), '05-puentes-correr.sql'];
  try {
    execFileSync('./correr.sh', [BD, ...archivos], { cwd: AQUI, env: { ...process.env, PGHOST: '127.0.0.1', PGPORT }, stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) { console.error('correr.sh falló:\n' + (e.stdout?.toString().split('\n').slice(-15).join('\n') ?? '') + (e.stderr?.toString().slice(-2000) ?? '')); process.exit(2); }
  const su = process.env.BANCO_SU ? process.env.BANCO_SU.split(' ') : (process.getuid && process.getuid() === 0 ? ['runuser', '-u', 'postgres', '--', 'psql'] : ['psql', '-U', 'postgres']);
  const envSu = { ...process.env }; delete envSu.PGHOST;
  execFileSync(su[0], [...su.slice(1), '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-p', PGPORT, '-d', BD, '-f', path.join(R, 'pruebas/seguridad/00-vault-shim.sql')], { env: envSu, stdio: ['ignore', 'pipe', 'pipe'] });
  q(`select fn_tarjeta_alta('1007', '2100-2013', 'Amex Business Gold (prueba Plaid)')`);
  psqlArchivo(path.join(D, 'c7-plaid.sql'));
  psqlArchivo(path.join(D, 's1-mfa.sql'));
  log('c1..c7 + s1 listos; p1-stripe.sql dos veces…');
  let pegado = '';
  try { psqlArchivo(path.join(D, 'p1-stripe.sql')); pegado = psqlArchivo(path.join(D, 'p1-stripe.sql'), ['-At']); }
  catch (e) { console.error('p1-stripe.sql falló:\n' + String(e.stderr || e.message).slice(-3000)); process.exit(2); }
  ok('E2E-01 p1-stripe.sql entra dos veces (idempotente) y enseña su tabla final', /stripe_rutina_secreto/.test(pegado) && /2026-09-30\.endive/.test(pegado), pegado.slice(-600));
  log('p1-pruebas.sql…');
  try {
    pruebasP1 = execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-At', '-c', '\\o /dev/null', '-f', path.join(D, 'p1-pruebas.sql'), '-c', '\\o',
      '-c', `select format('total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok), count(*) filter (where ok is null)) || coalesce(' · ' || string_agg(n || ' ' || prueba, '; ') filter (where ok is not true), '') from _pruebas`],
      { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20 }).toString().trim();
  } catch (e) { pruebasP1 = 'error: ' + String(e.stderr || e.message).slice(-1500); }
  ok('E2E-01 p1-pruebas.sql en verde (42 de 42)', /^total=42 ok=42 fallan=0/.test(pruebasP1), pruebasP1);
  // el banco: las facturas de la semilla en el libro (como la guía del lector 4) y diez de prueba, redondas
  q(`select fn_mapeo_confirmar('tipo_proyecto', 'residencial'); select fn_mapeo_confirmar('tipo_proyecto', 'comercial');
     update facturas set retencion = 0 where id = 2;
     insert into facturas (proyecto_id, num, fecha, monto, retencion, estado, pagada)
     select 'casa-perez-k3m9', n::text, current_date - 1, m, 0, 'emitida', false
       from (values (1104, 1000.00), (1105, 600.00), (1106, 700.00), (1107, 300.00), (1108, 800.00), (1109, 900.00), (1110, 500.00),
                    (1111, 450.00), (1112, 350.00), (1113, 250.00), (1114, 400.00)) v(n, m);
     select fn_puentes_correr();
     update stripe_config set acepta_prueba = true where id = 1;`);
  // re-pegar las capas con p1 puesto: nada de p1 cuelga de sus vistas
  log('re-pego c1, c3, c4, c6, c7 y s1 con p1 puesto…');
  const repegar = [];
  for (const f of ['c1-plan-de-cuentas', 'c3-puentes', 'c4-estados', 'c6-banco', 'c7-plaid', 's1-mfa']) {
    try { psqlArchivo(path.join(D, `${f}.sql`)); } catch (e) { repegar.push(`${f}: ${String(e.stderr || e.message).split('\n').find((l) => /ERROR/.test(l)) ?? 'falló'}`); }
  }
  ok('E2E-02 c1, c3, c4, c6, c7 y s1 se vuelven a pegar con p1 puesto (sin MX000)', repegar.length === 0, repegar);
  ok('E2E-02 la 1020 y la 1140 siguen, con su fila de los estados', q(`select count(*) from cuentas c join estados_mapeo m on m.cuenta = c.codigo where c.codigo in ('1020', '1140') and c.activa`) === '2');
}
const fid = Object.fromEntries(q(`select num || '=' || id from facturas`).split('\n').map((l) => l.split('=')).map(([n, i]) => [n, Number(i)]));
const dueno = q(`select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1`);
const equipo = q(`select id from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1`);
const RUTINA = q(`select decrypted_secret from vault.decrypted_secrets where name = 'stripe_rutina_secreto'`);
ok('hay dueño, equipo, el secreto de la rutina y las facturas de prueba en el libro',
   dueno && equipo && RUTINA.length >= 32 && q(`select count(*) from facturas_cobro where num in ('1101', '1102', '1103', '1104', '1113') and saldo_cxc > 0`) === '5',
   { dueno, equipo, saldos: q(`select string_agg(num || '=' || saldo_cxc, ' ') from facturas_cobro`) });
const pegadoFilas = q(`select que || ' → ' || detalle from fn_stripe_pegado()`);
ok('E2E-01 fn_stripe_pegado enseña el secreto de la rutina, la URL, la versión y los 20 eventos',
   pegadoFilas.includes(RUTINA) && /URL del webhook → https:\/\/.+\/functions\/v1\/stripe/.test(pegadoFilas) && /versión de API → 2026-09-30\.endive/.test(pegadoFilas)
   && (pegadoFilas.match(/eventos \(márcalos en Stripe\) → (.*)/)?.[1] ?? '').split(', ').length === 20, pegadoFilas.slice(0, 600));

// ---- 2. el Stripe simulado y la función ---------------------------------
const hijos = [];
const limpiarHijos = () => { for (const h of hijos) { try { h.kill(); } catch { /* ya */ } } };
process.on('exit', limpiarHijos);
const simulador = spawn(process.execPath, [path.join(AQUI, 'stripe-simulado.mjs'), String(P_SIM)], { stdio: ['ignore', 'pipe', 'inherit'], env: { ...process.env, STRIPE_SECRET_KEY: LLAVE } });
hijos.push(simulador);
await new Promise((res) => simulador.stdout.once('data', res));
const sim = async (ruta, cuerpo = {}) => {
  const r = await fetch(`http://127.0.0.1:${P_SIM}${ruta}`, { method: 'POST', body: JSON.stringify(cuerpo) });
  const j = await r.json();
  if (!r.ok) throw new Error(`simulado ${ruta}: ${JSON.stringify(j)}`);
  return j;
};
const ENTORNO = {
  STRIPE_SECRET_KEY: LLAVE, STRIPE_WEBHOOK_SECRET: WHSEC, STRIPE_RUTINA_SECRETO: RUTINA, STRIPE_BASE_URL: `http://127.0.0.1:${P_SIM}`,
  MXP_DB_URL: `postgres://editor_sql:editor_sql@127.0.0.1:${PGPORT}/${BD}`, MXP_BANCO_PRUEBAS: '1', SUPABASE_URL: `http://127.0.0.1:${P_FN}`,
};
let salidaFn = '';
let atenderNode = null, modulo = null;
// La base del modo node: psql por llamada, en su transacción, con los claims vacíos (como abrirBase)
function basePsql(puerto) {
  const dolar = (s) => { let tag = 'mxp'; while (s.includes(`$${tag}$`)) tag += 'x'; return `$${tag}$${s}$${tag}$`; };
  const literal = (v) => v === null || v === undefined ? 'NULL' : typeof v === 'number' ? String(v) : typeof v === 'boolean' ? String(v) : dolar(typeof v === 'string' ? v : JSON.stringify(v));
  return {
    async rpc(fn, args) {
      if (!/^fn_stripe_[a-z_]+$/.test(fn)) throw Object.assign(new Error(`función que no es de p1: ${fn}`), { code: '42501' });
      const llamada = `select ${fn}(${Object.keys(args).map((k) => `${k} => ${literal(args[k])}`).join(', ')}) as r;`;
      const r = await psqlAsync(`\\set ON_ERROR_STOP 1\n\\set VERBOSITY verbose\nbegin;\nselect set_config('request.jwt.claims', '', true) as a, set_config('request.jwt.claim.sub', '', true) as b \\gset x_\n${llamada}\ncommit;\n`, puerto);
      if (r.codigo !== 0) {
        const m = r.error.match(/ERROR:\s+([0-9A-Z]{5}):\s+(.*)/);
        const h = r.error.match(/HINT:\s+(.*)/);
        throw Object.assign(new Error(m ? m[2] : r.error.trim().split('\n')[0]), { code: m ? m[1] : undefined, hint: h ? h[1] : undefined });
      }
      const t = r.salida.trim();
      if (!t) return null;
      try { return JSON.parse(t); } catch { return t; }
    },
    async quien(jwt) {
      let carga = null;
      try { carga = JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString()); } catch { return null; }
      if (!/^[0-9a-f-]{36}$/.test(carga?.sub ?? '')) return null;
      const r = await psqlAsync(`select rol || '|' || coalesce(activo, true) from perfiles where id = '${carga.sub}';`, puerto);
      const [rol, activo] = r.salida.trim().split('|');
      return rol ? { id: carga.sub, rol, activo: activo === 't' || activo === 'true' } : null;
    },
  };
}
async function arrancarDeno(puerto, extra = {}) {
  const h = spawn(DENO, ['run', '--quiet', '-A', path.join(R, 'supabase/functions/stripe/index.ts')], {
    stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...ENTORNO, ...extra, MXP_PUERTO: String(puerto) },
  });
  hijos.push(h);
  h.stdout.on('data', (d) => { salidaFn += d; }); h.stderr.on('data', (d) => { salidaFn += d; });
  for (let i = 0; i < 120; i++) {
    try { const r = await fetch(`http://127.0.0.1:${puerto}/?paso=salud`); if (r.ok) return h; } catch { /* todavía no */ }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('la función en Deno no arrancó:\n' + salidaFn.slice(-2000));
}
if (CON_DENO) {
  log(`modo deno (${DENO})`);
  await arrancarDeno(P_FN);
} else {
  log('modo node (sin Deno): la función se importa aquí y la base es psql');
  Object.assign(process.env, ENTORNO);
  const errorOriginal = console.error;
  console.error = (...a) => { salidaFn += a.map(String).join(' ') + '\n'; };
  process.on('exit', () => { console.error = errorOriginal; });
  modulo = await import(pathToFileURL(path.join(R, 'supabase/functions/stripe/index.ts')).href);
  modulo.usarBaseDePruebas(basePsql(PGPORT));
  atenderNode = modulo.atender;
}
// Una llamada a la función (en Deno por HTTP; en node, a atender directo)
async function pedir(req, puerto = P_FN) {
  if (atenderNode) return await atenderNode(req);
  const u = new URL(req.url);
  return await fetch(`http://127.0.0.1:${puerto}${u.pathname}${u.search}`, { method: req.method, headers: req.headers, body: req.method === 'GET' ? undefined : await req.text() });
}
async function llamar(cuerpo, { jwt: tok, rutina, metodo = 'POST', consulta = '', puerto } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (tok) headers.Authorization = `Bearer ${tok}`;
  if (rutina !== undefined) headers['x-mxp-rutina'] = rutina;
  const req = new Request(`http://127.0.0.1:${P_FN}/functions/v1/stripe${consulta}`, { method: metodo, headers, body: metodo === 'GET' ? undefined : JSON.stringify(cuerpo) });
  const r = await pedir(req, puerto);
  const texto = await r.text();
  respuestas.push(texto);
  let j = null; try { j = JSON.parse(texto); } catch { /* sin json */ }
  return { estado: r.status, j };
}
async function webhook(ev, { t = Math.floor(Date.now() / 1000), secreto = WHSEC, falsa = false, cuerpo, cabecera, puerto } = {}) {
  const crudo = JSON.stringify(ev);
  const firma = cabecera ?? (falsa ? firmarConFalsa(crudo, secreto, t) : firmar(crudo, secreto, t));
  const req = new Request(`http://127.0.0.1:${P_FN}/functions/v1/stripe`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Stripe-Signature': firma }, body: cuerpo ?? crudo });
  const r = await pedir(req, puerto);
  const texto = await r.text();
  respuestas.push(texto);
  let j = null; try { j = JSON.parse(texto); } catch { /* sin json */ }
  return { estado: r.status, j };
}
const de = (eventos, tipo) => eventos.find((e) => e.type === tipo);
async function mandar(eventos, tipos) { const rs = []; for (const t of tipos) rs.push(await webhook(de(eventos, t))); return rs; }
// Otra instancia con otro entorno (Deno: otro proceso; node: el entorno de este, un rato)
async function conEntorno(extra, fn) {
  if (!atenderNode) {
    const h = await arrancarDeno(P_FN2, extra);
    try { return await fn(P_FN2); } finally { h.kill(); }
  }
  const antes = Object.fromEntries(Object.keys(extra).map((k) => [k, process.env[k]]));
  Object.assign(process.env, extra);
  try { return await fn(undefined); } finally { for (const [k, v] of Object.entries(antes)) { if (v === undefined) delete process.env[k]; else process.env[k] = v; } }
}
const b64u = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (sub, aal = 'aal2') => `${b64u({ alg: 'none', typ: 'JWT' })}.${b64u({ sub, role: 'authenticated', aal, exp: 4102444800 })}.firma`;
const D2 = jwt(dueno), D1 = jwt(dueno, 'aal1'), E2 = jwt(equipo);
const saldo = (c) => q(`select coalesce(sum(monto), 0)::numeric(14,2) from asiento_lineas where cuenta = '${c}'`);
const cuadresRojos = () => q(`select coalesce(string_agg(orden || ' ' || control || ': ' || coalesce(detalle, ''), ' | ' order by orden), 'ninguno') from v_stripe_control where nivel = 'cuadre' and not ok`);
const vivos = (pi) => q(`select count(*) || '|' || coalesce(sum(c.monto), 0) from cobros c where c.referencia = ${lit(pi)} and c.cuenta = '1020' and c.estado <> 'anulado' and not exists (select 1 from cobros_devoluciones d where d.cobro_id = c.id)`);
const pago = (pi, cols = 'estado') => q(`select ${cols} from stripe_pagos where pi = ${lit(pi)}`);
const pagoPantalla = (pi) => q(`select estado_pantalla from v_stripe_pagos where pi = ${lit(pi)}`);
const llamadasSim = async () => (await sim('/__estado')).llamadas;
const lineasDe = (asiento) => q(`select string_agg(l.cuenta || ' ' || l.monto, ' | ' order by l.orden) from asiento_lineas l where l.asiento_id = ${lit(asiento)}`);
function importarDeposito(id, fecha, monto, desc, casar = true) {
  // como la sincronización de la mañana (fn_plaid_recibir): en nombre del dueño, un lote de origen plaid y «Casar»
  const lote = { origen: 'plaid', cuenta: '1010', nombre: `Plaid · e2e stripe · ${id}`,
                 filas: [{ id, fecha, plaid_monto: (-Number(monto)).toFixed(2), descripcion: desc ?? `ORIG CO NAME:STRIPE CO ENTRY DESCR:TRANSFER SEC:CCD IND ID:ST-${id.toUpperCase()}`, tipo: 'XFER', pendiente: false }] };
  return `begin;
    select set_config('request.jwt.claims', ${lit(JSON.stringify({ sub: dueno, role: 'authenticated' }))}, true) as a, set_config('request.jwt.claim.sub', ${lit(dueno)}, true) as b \\gset x_
    select fn_banco_importar_filas(${lit(JSON.stringify(lote))}::jsonb) is not null as i \\gset x_
    ${casar ? "select fn_banco_casar_todo('1010') is not null as c \\gset x_" : ''}
    commit;`;
}
async function deposito(id, fecha, monto, desc, casar = true) {
  const r = await psqlAsync(`\\set ON_ERROR_STOP 1\n${importarDeposito(id, fecha, monto, desc, casar)}\n`);
  if (r.codigo !== 0) throw new Error(`importar ${id}: ${r.error.slice(0, 600)}`);
  return q(`select id from movimientos_banco where id_externo = ${lit(id)} order by importado_el desc limit 1`);
}
const casadoDe = (po) => q(`select coalesce(bc.regla, '-') || '|' || case when bc.automatico then 't' else 'f' end || '|' || coalesce(bc.motivo, 'sin motivo') from stripe_payouts p join asiento_lineas al on al.asiento_id = p.asiento_llegada and al.cuenta = '1010' join banco_casado_lineas bcl on bcl.asiento_id = al.asiento_id and bcl.orden = al.orden and bcl.vigente join banco_casados bc on bc.id = bcl.casado_id and bc.deshecho_el is null where p.po = ${lit(po)}`);
async function rutina() { return await llamar({ accion: 'barrer' }, { rutina: RUTINA }); }
async function crearEnlace(num, extra = {}) { return await llamar({ accion: 'crear_enlace', factura_id: fid[num], ...extra }, { jwt: D2 }); }

try {
  // ---- E2E-03 salud ---------------------------------------------------------
  let r = await llamar(null, { metodo: 'GET', consulta: '?paso=salud' });
  ok('E2E-03 salud: ok, modo prueba, llave restringida, webhook, rutina, base, banco de pruebas, nada falta',
     r.estado === 200 && r.j.ok && r.j.modo === 'prueba' && r.j.llave_restringida && r.j.webhook && r.j.rutina && r.j.base && r.j.banco_de_pruebas && r.j.version === '2026-09-30.endive' && r.j.falta.length === 0, r.j);
  ok('E2E-03 salud no enseña ninguna llave', ![LLAVE, WHSEC, RUTINA].some((s) => JSON.stringify(r.j).includes(s)));
  r = await conEntorno({ STRIPE_SECRET_KEY: 'sk_test_x' }, (p) => llamar({ accion: 'estado' }, { jwt: D2, puerto: p }));
  ok('E2E-03 con una llave secreta (sk_) → 500 CONFIG «llave RESTRINGIDA»', r.estado === 500 && r.j.codigo === 'CONFIG' && /RESTRINGIDA/.test(r.j.error), r);
  r = await conEntorno({ STRIPE_SECRET_KEY: 'sk_test_x' }, (p) => llamar(null, { metodo: 'GET', consulta: '?paso=salud', puerto: p }));
  r = await conEntorno({ MXP_DB_URL: 'postgres://u:p@db.ejemplo-prod.supabase.co:5432/postgres' }, (p) => llamar(null, { metodo: 'GET', consulta: '?paso=salud', puerto: p }));
  const r3b = await conEntorno({ MXP_DB_URL: 'postgres://u:p@db.ejemplo-prod.supabase.co:5432/postgres' }, (p) => llamar({ accion: 'estado' }, { jwt: D2, puerto: p }));
  const r3c = await conEntorno({ SUPABASE_DB_URL: 'postgres://u:p@db.ejemplo-prod.supabase.co:5432/postgres' }, (p) => llamar({ accion: 'estado' }, { jwt: D2, puerto: p }));
  ok('E2E-03 MXP_BANCO_PRUEBAS fuera del banco (la base no es 127.0.0.1, o hay SUPABASE_DB_URL): no es el banco, salud lo dice y todo → 500 CONFIG',
     r.estado === 200 && r.j.banco_de_pruebas === false && r.j.falta.some((f) => /MXP_BANCO_PRUEBAS no vale/.test(f))
     && r3b.estado === 500 && r3b.j.codigo === 'CONFIG' && /MXP_BANCO_PRUEBAS/.test(r3b.j.error)
     && r3c.estado === 500 && r3c.j.codigo === 'CONFIG', [r.j, r3b.j, r3c.j]);
  r = await conEntorno({ STRIPE_SECRET_KEY: 'sk_test_x' }, (p) => llamar(null, { metodo: 'GET', consulta: '?paso=salud', puerto: p }));
  ok('E2E-03 salud dice qué falta (la llave restringida) sin enseñarla', r.estado === 200 && r.j.llave === true && r.j.llave_restringida === false && r.j.falta.some((f) => /RESTRINGIDA/.test(f)) && !JSON.stringify(r.j).includes('sk_test_x'), r.j);

  // ---- E2E-04 quién --------------------------------------------------------
  r = await llamar({ accion: 'estado' });
  ok('E2E-04 sin sesión → 401 SESION', r.estado === 401 && r.j.codigo === 'SESION', r);
  r = await llamar({ accion: 'crear_enlace', factura_id: fid['1103'] }, { jwt: E2 });
  ok('E2E-04 el equipo (aal2) → 403 NO_DUENO', r.estado === 403 && r.j.codigo === 'NO_DUENO', r);
  r = await llamar({ accion: 'crear_enlace', factura_id: fid['1103'] }, { jwt: D1 });
  const r2 = await llamar({ accion: 'estado' }, { jwt: D1 });
  ok('E2E-04 el dueño sin el código del teléfono (aal1) → 403 MFA en crear_enlace y en estado', r.estado === 403 && r.j.codigo === 'MFA' && r2.estado === 403 && r2.j.codigo === 'MFA', [r, r2]);
  r = await llamar({ accion: 'estado' }, { jwt: D2 });
  ok('E2E-04 el dueño en aal2: estado 200 con la configuración, el control y la salud', r.estado === 200 && r.j.ok && r.j.resumen?.config?.cuenta_puente === '1020' && Array.isArray(r.j.resumen?.control_rojo) && r.j.salud?.ok, r.j);
  r = await llamar({ accion: 'nada' }, { jwt: D2 });
  ok('E2E-04 acción desconocida → 400 ACCION', r.estado === 400 && r.j.codigo === 'ACCION', r);
  r = await llamar({ accion: 'barrer' }, { rutina: 'x'.repeat(64) });
  ok('E2E-04 la rutina con otro secreto → 401', r.estado === 401, r);
  r = await llamar({ accion: 'crear_enlace' }, { rutina: RUTINA });
  ok('E2E-04 la rutina solo sabe barrer → 400', r.estado === 400, r);
  ok('E2E-04 nada de eso tocó la base', q(`select count(*) from stripe_enlaces`) === '0');

  // ---- E2E-05 crear el enlace de la 1103 -----------------------------------
  const huellaFacturas = () => q(`select md5(string_agg(concat_ws('|', id, pagada, cobrado, cobrada_el, metodo_cobro, link_pago, estado), ',' order by id)) from facturas`);
  const huella0 = huellaFacturas();
  let antes = (await llamadasSim()).length;
  r = await crearEnlace('1103');
  let ll = (await llamadasSim()).slice(antes);
  const post = ll.filter((l) => l.metodo === 'POST' && l.ruta === '/v1/payment_links');
  const enlace1 = r.j?.enlace;
  const cp = post[0]?.cuerpo ?? {};
  ok('E2E-05 crear_enlace 1103: 200, nuevo, con su url', r.estado === 200 && r.j.nuevo === true && /^http:\/\/127\.0\.0\.1:\d+\/pagar\/plink_/.test(enlace1?.url ?? '') && enlace1?.monto === 8000 && enlace1.con_retencion === false, r.j);
  ok('E2E-05 Stripe recibió UN POST /v1/payment_links con Bearer, la versión, la Idempotency-Key mxp-enlace-<id> y el cuerpo exacto',
     post.length === 1 && post[0].bearer && post[0].version === '2026-09-30.endive' && post[0].idem === `mxp-enlace-${enlace1?.id}`
     && cp.line_items?.[0]?.price_data?.unit_amount === '800000' && cp.line_items[0].price_data.currency === 'usd' && cp.line_items[0].quantity === '1'
     && /^Factura \/ Invoice 1103 · Max Power Electrical Solutions$/.test(cp.line_items[0].price_data.product_data?.name ?? '')
     && JSON.stringify(cp.payment_method_types) === '["us_bank_account","card"]' && cp.restrictions?.completed_sessions?.limit === '1'
     && cp.metadata?.mxp === 'p1' && cp.metadata.enlace === enlace1?.id && cp.metadata.factura_id === String(fid['1103']) && cp.metadata.factura === '1103' && cp.metadata.retencion === 'no'
     && JSON.stringify(cp.payment_intent_data?.metadata) === JSON.stringify(cp.metadata) && cp.after_completion?.type === 'hosted_confirmation' && /1103/.test(cp.after_completion?.hosted_confirmation?.custom_message ?? '')
     && /ya no está activo/.test(cp.inactive_message ?? ''), post);
  ok('E2E-05 el enlace queda activo con su plink y su url; la factura no se toca (pagada, cobrado, link_pago…)',
     q(`select estado || '|' || plink || '|' || url from stripe_enlaces where id = ${lit(enlace1?.id)}`) === `activo|${enlace1?.plink}|${enlace1?.url}` && huellaFacturas() === huella0);
  antes = (await llamadasSim()).length;
  r = await crearEnlace('1103');
  ok('E2E-05 segundo toque: el mismo enlace, sin llamar a Stripe', r.estado === 200 && r.j.nuevo === false && r.j.enlace?.id === enlace1?.id && r.j.desfasado === false && (await llamadasSim()).length === antes, r.j);
  antes = (await llamadasSim()).length;
  r = await crearEnlace('1103', { reemplazar: true });
  ll = (await llamadasSim()).slice(antes);
  const enlace1103 = r.j?.enlace;
  ok('E2E-05 reemplazar: POST active=false al viejo (mxp-baja-<id>) y uno nuevo',
     r.estado === 200 && r.j.nuevo === true && enlace1103?.id !== enlace1?.id
     && ll.some((l) => l.metodo === 'POST' && l.ruta === `/v1/payment_links/${enlace1?.plink}` && l.cuerpo.active === 'false' && l.idem === `mxp-baja-${enlace1?.id}`)
     && ll.filter((l) => l.metodo === 'POST' && l.ruta === '/v1/payment_links').length === 1
     && q(`select estado || '|' || desactivado_motivo || '|' || desactivado_por from stripe_enlaces where id = ${lit(enlace1?.id)}`) === 'desactivado|reemplazado por uno nuevo|pantalla'
     && q(`select reemplaza_a from stripe_enlaces where id = ${lit(enlace1103?.id)}`) === enlace1?.id, { r: r.j, ll });

  // ---- E2E-06 Stripe caído al crear ------------------------------------------
  await sim('/__caer', { veces: 1000 });
  r = await crearEnlace('1102');
  await sim('/__caer', { veces: 0 });
  const creando = q(`select id || '|' || estado || '|' || idempotencia from stripe_enlaces where factura_id = ${fid['1102']}`).split('|');
  ok('E2E-06 Stripe caído al crear: 502 STRIPE_CAIDO y el enlace queda «creando»', r.estado === 502 && r.j.codigo === 'STRIPE_CAIDO' && creando[1] === 'creando', { r, creando });
  q(`update stripe_enlaces set creado_el = now() - interval '10 minutes' where id = ${lit(creando[0])}`);
  antes = (await llamadasSim()).length;
  r = await rutina();
  ll = (await llamadasSim()).slice(antes);
  const links1102 = (await sim('/__estado')).links.filter((l) => l.metadata?.enlace === creando[0]);
  const plink1102 = q(`select plink from stripe_enlaces where id = ${lit(creando[0])}`);
  ok('E2E-06 la rutina lo termina con la MISMA Idempotency-Key: un solo plink en Stripe y el enlace activo',
     r.estado === 200 && r.j.resumen?.enlaces_terminados === 1 && links1102.length === 1 && plink1102 === links1102[0].id
     && ll.filter((l) => l.metodo === 'POST' && l.ruta === '/v1/payment_links').every((l) => l.idem === creando[2])
     && q(`select estado from stripe_enlaces where id = ${lit(creando[0])}`) === 'activo', { resumen: r.j?.resumen, links1102 });

  // ---- E2E-07 la casilla «pagada» y los permisos de la llave -----------------
  r = await crearEnlace('1101');
  ok('E2E-07 la 1101 (casilla «pagada», el libro dice que debe): 409 MX008 con la pista pagada_en_app', r.estado === 409 && r.j.codigo === 'MX008' && r.j.pista === 'pagada_en_app', r);
  await sim('/__sin_permiso', { ruta: '/v1/payment_links', metodo: 'POST', rak: 'rak_payment_link_write' });
  r = await crearEnlace('1101', { aunque_pagada: true });
  ok('E2E-07 sin el permiso de escribir Payment Links: 502 STRIPE_PERMISO con su rak, sin la llave en el mensaje, y el enlace «fallido»',
     r.estado === 502 && r.j.codigo === 'STRIPE_PERMISO' && r.j.rak === 'rak_payment_link_write' && !/rk_test/.test(r.j.error)
     && q(`select estado from stripe_enlaces where factura_id = ${fid['1101']}`) === 'fallido', r);
  await sim('/__sin_permiso', { limpiar: true });
  await sim('/__sin_permiso', { ruta: '/v1/disputes', rak: 'rak_dispute_read' });
  r = await llamar({ accion: 'probar_llave' }, { jwt: D2 });
  await sim('/__sin_permiso', { limpiar: true });
  const disp = r.j?.permisos?.find((p) => p.recurso === 'Disputes');
  ok('E2E-07 probar_llave: cada recurso con ✓/✗, el rak que falta y su nombre en el panel', r.estado === 200 && r.j.ok && r.j.todos === false && r.j.restringida && r.j.permisos.length === 10
     && disp?.ok === false && disp.rak === 'rak_dispute_read' && disp.panel === 'Disputes: Read' && r.j.permisos.filter((p) => p.ok).length === 9, r.j);
  // la llave puede leer movimientos pero no expandir su origen (lo que pide el depósito de verdad)
  await sim('/__sin_permiso', { ruta: '/v1/balance_transactions', expand: 'data.source', rak: 'rak_balance_transaction_source_read' });
  antes = (await llamadasSim()).length;
  r = await llamar({ accion: 'probar_llave' }, { jwt: D2 });
  await sim('/__sin_permiso', { limpiar: true });
  const btp = r.j?.permisos?.find((p) => /^Balance transactions/.test(p.recurso));
  const llProbar = (await llamadasSim()).slice(antes);
  ok('E2E-07 probar_llave hace las mismas llamadas que la función (con expand) y caza «Balance transaction sources»',
     r.estado === 200 && btp?.ok === false && btp.rak === 'rak_balance_transaction_source_read' && btp.panel === 'Balance transaction sources: Read'
     && llProbar.some((l) => l.ruta === '/v1/charges' && JSON.stringify(l.consulta).includes('data.balance_transaction'))
     && llProbar.some((l) => l.ruta === '/v1/balance') && r.j.permisos.find((p) => p.recurso === 'Balance')?.ok === true, { permisos: r.j?.permisos, llProbar });

  // ---- E2E-08 la firma ---------------------------------------------------------
  const evF = { id: 'evt_FIRMA0001', object: 'event', type: 'customer.created', api_version: '2026-09-30.endive', created: Math.floor(Date.now() / 1000), livemode: false, data: { object: { id: 'cus_FIRMA', object: 'customer' } } };
  const ahora = Math.floor(Date.now() / 1000);
  const malas = [
    ['firma con otro secreto (otro endpoint)', await webhook(evF, { secreto: 'whsec_otro' })],
    ['t de hace 301 s', await webhook(evF, { t: ahora - 301 })],
    ['t de dentro de 301 s', await webhook(evF, { t: ahora + 301 })],
    ['cuerpo alterado', await webhook(evF, { cuerpo: JSON.stringify({ ...evF, type: 'payout.paid' }) })],
    ['cabecera sin v1', await webhook(evF, { cabecera: `t=${ahora}` })],
  ];
  for (const [nombre, x] of malas) ok(`E2E-08 ${nombre} → 400 FIRMA`, x.estado === 400 && x.j?.codigo === 'FIRMA', x);
  ok('E2E-08 nada de eso entró a stripe_eventos', q(`select count(*) from stripe_eventos`) === '0');
  r = await webhook(evF, { falsa: true });
  ok('E2E-08 dos v1 (una falsa delante, como en la rotación del secreto) → 200; el aviso queda guardado e ignorado', r.estado === 200 && r.j.ok && q(`select estado from stripe_eventos where id = 'evt_FIRMA0001'`) === 'ignorado', r);
  r = await webhook(evF);
  ok('E2E-08 el mismo aviso otra vez → 200 repetido, una sola fila', r.estado === 200 && r.j.repetido === true && q(`select veces from stripe_eventos where id = 'evt_FIRMA0001'`) === '2', r);

  // ---- E2E-09 tarjeta en la 1103: avisos repetidos y desordenados -------------
  let p = await sim('/__pagar', { plink: enlace1103.plink, medio: 'tarjeta' });
  const PI_1103 = p.pi;
  let ev = p.eventos;
  const rs9 = [];
  rs9.push(await webhook(de(ev, 'charge.succeeded')));
  rs9.push(...await Promise.all([webhook(de(ev, 'payment_intent.succeeded')), webhook(de(ev, 'checkout.session.completed'))]));
  rs9.push(await webhook(de(ev, 'payment_intent.succeeded')), await webhook(de(ev, 'payment_intent.succeeded')), await webhook(de(ev, 'payment_link.updated')));
  ok('E2E-09 seis entregas → todas 200', rs9.every((x) => x.estado === 200 && x.j.ok), rs9);
  ok('E2E-09 un solo cobro vivo de 8,000.00 en la 1020 (referencia = el pi)', vivos(PI_1103) === '1|8000.00' && saldo('1020') === '8000.00', vivos(PI_1103));
  ok('E2E-09 los repetidos contestan repetido:true y el aviso suma sus veces', rs9.filter((x) => x.j?.repetido === true).length >= 2 && q(`select veces from stripe_eventos where id = ${lit(de(ev, 'payment_intent.succeeded').id)}`) === '3', rs9.map((x) => x.j));
  ok('E2E-09 cada aviso guarda la versión con que Stripe lo mandó, y la de la app no avisa',
     q(`select api_version from stripe_eventos where id = ${lit(de(ev, 'payment_intent.succeeded').id)}`) === '2026-09-30.endive'
     && q(`select count(*) from stripe_avisos where clave = 'version'`) === '0');
  ok('E2E-09 los avisos quedan «hecho»', q(`select string_agg(distinct estado, ',') from stripe_eventos where objeto_id in (${lit(PI_1103)}, ${lit(p.sesion)}, ${lit(p.cargo)})`) === 'hecho');
  ok('E2E-09 el pago «cobrado» (objetivo = en el libro = 8,000.00), el enlace «usado», en nombre del dueño con la fecha del aviso',
     pago(PI_1103, `estado || '|' || objetivo || '|' || en_libro || '|' || medio`) === 'cobrado|8000.00|8000.00|tarjeta'
     && q(`select estado from stripe_enlaces where id = ${lit(enlace1103.id)}`) === 'usado'
     && q(`select c.creado_por || '|' || a.usuario_id || '|' || c.fecha || '|' || c.llave_cliente from cobros c join asientos a on a.id = c.contabilizado_en where c.referencia = ${lit(PI_1103)}`) === `${dueno}|${dueno}|${HOY}|stripe:${PI_1103}`,
     q(`select c.creado_por || '|' || a.usuario_id || '|' || c.fecha || '|' || c.llave_cliente from cobros c join asientos a on a.id = c.contabilizado_en where c.referencia = ${lit(PI_1103)}`));
  ok('E2E-09 el control de p1 sin cuadres rojos', cuadresRojos() === 'ninguno', cuadresRojos());

  // ---- E2E-10 ACH en la 1101: en camino → liquidado ----------------------------
  r = await crearEnlace('1101', { aunque_pagada: true });
  const enlace1101 = r.j?.enlace;
  ok('E2E-10 crear_enlace 1101 confirmando que la debe (aunque_pagada) → 200', r.estado === 200 && r.j.nuevo && enlace1101?.monto === 5000, r);
  p = await sim('/__pagar', { plink: enlace1101.plink, medio: 'ach' });
  const PI_1101 = p.pi;
  ev = p.eventos;
  await mandar(ev, ['checkout.session.completed', 'payment_intent.processing']);
  ok('E2E-10 ACH procesando: «en camino», sin asiento', pago(PI_1101, `estado || '|' || en_libro || '|' || medio`) === 'en_camino|0.00|ach' && vivos(PI_1101) === '0|0' && pagoPantalla(PI_1101) === 'en_camino');
  r = await crearEnlace('1101', { aunque_pagada: true });
  ok('E2E-10 con un ACH en camino no se crea otro enlace → 409 MX008', r.estado === 409 && r.j.codigo === 'MX008' && /en camino/.test(r.j.error), r);
  const liq = await sim('/__liquidar', { pi: PI_1101 });
  await mandar(liq.eventos, ['checkout.session.async_payment_succeeded']);
  ok('E2E-10 liquidado (solo async_payment_succeeded): el cobro de 5,000.00 entra', vivos(PI_1101) === '1|5000.00' && pago(PI_1101) === 'cobrado', vivos(PI_1101));
  await mandar(liq.eventos, ['payment_intent.succeeded', 'charge.succeeded']);
  await mandar(ev, ['payment_intent.processing', 'checkout.session.completed']);
  ok('E2E-10 los demás avisos (y los viejos de «procesando») no cambian nada', vivos(PI_1101) === '1|5000.00' && pago(PI_1101) === 'cobrado' && q(`select count(*) from stripe_pago_libro l join stripe_pagos s on s.id = l.pago_id where s.pi = ${lit(PI_1101)}`) === '1');

  // ---- E2E-12 reembolso parcial en la 1103 ------------------------------------
  const re = await sim('/__reembolsar', { pi: PI_1103, monto: 100000 });
  await mandar(re.eventos, ['refund.updated', 'charge.refunded', 'refund.created']);
  ok('E2E-12 reembolso de 1,000.00: una devolución de 8,000.00 y un cobro de 7,000.00 (llave :v1, misma referencia)',
     q(`select string_agg(l.accion || ' ' || l.monto || coalesce(' ' || l.llave, ''), ' | ' order by l.id) from stripe_pago_libro l join stripe_pagos s on s.id = l.pago_id where s.pi = ${lit(PI_1103)}`)
       === `cobro 8000.00 stripe:${PI_1103} | devolucion -8000.00 | cobro 7000.00 stripe:${PI_1103}:v1` && vivos(PI_1103) === '1|7000.00',
     q(`select string_agg(l.accion || ' ' || l.monto, ' | ' order by l.id) from stripe_pago_libro l join stripe_pagos s on s.id = l.pago_id where s.pi = ${lit(PI_1103)}`));
  ok('E2E-12 la 1103 vuelve a deber 1,000.00; la 1020 = 12,000.00; el control sin cuadres rojos',
     q(`select saldo_cxc from v_stripe_facturas where factura_id = ${fid['1103']}`) === '1000.00' && saldo('1020') === '12000.00' && cuadresRojos() === 'ninguno', [saldo('1020'), cuadresRojos()]);

  // ---- E2E-14 el depósito: varios cobros, comisiones, en páginas ---------------
  await sim('/__fee', { monto: 150, descripcion: 'Cargo de prueba' });
  await sim('/__pagina', { n: 2 });
  const po1 = await sim('/__payout', { conciliacion: 'in_progress' });
  ok('E2E-14 Stripe junta 11,761.20 netos', po1.monto === 1176120, po1);
  antes = (await llamadasSim()).length;
  await mandar(po1.eventos, ['payout.paid']);
  ok('E2E-14 payout.paid sin la composición todavía (in_progress): «esperando_composicion», sin asientos ni pedir el detalle',
     q(`select estado || '|' || coalesce(asiento_salida::text, '-') from stripe_payouts where po = ${lit(po1.po)}`) === 'esperando_composicion|-'
     && !(await llamadasSim()).slice(antes).some((l) => l.ruta === '/v1/balance_transactions'));
  const conc = await sim('/__payout_conciliar', { po: po1.po });
  antes = (await llamadasSim()).length;
  await mandar(conc.eventos, ['payout.reconciliation_completed']);
  ll = (await llamadasSim()).slice(antes).filter((l) => l.ruta === '/v1/balance_transactions');
  await sim('/__pagina', { n: 100 });
  const P = q(`select asiento_salida || '|' || asiento_llegada || '|' || estado from stripe_payouts where po = ${lit(po1.po)}`).split('|');
  ok('E2E-14 reconciliation_completed: la composición en páginas de 2 (has_more, starting_after)', ll.length >= 3 && ll.slice(1).every((l) => l.consulta.starting_after && l.consulta.payout === po1.po), ll.map((l) => l.consulta));
  ok('E2E-14 P1 Dr 1140 11,761.20 + Dr 6130 238.80 / Cr 1020 12,000.00', P[2] === 'asentado' && lineasDe(P[0]) === '1140 11761.20 | 6130 238.80 | 1020 -12000.00', lineasDe(P[0]));
  ok('E2E-14 P2 Dr 1010 11,761.20 / Cr 1140', lineasDe(P[1]) === '1010 11761.20 | 1140 -11761.20', lineasDe(P[1]));
  ok('E2E-14 P1 y P2 a mano, sin origen ni documento_ruta, con la procedencia de Stripe',
     q(`select string_agg(camino || ' ' || coalesce(origen_tabla, '-') || ' ' || coalesce(documento_ruta, '-') || ' ' || (procedencia->>'payout') || ' ' || (procedencia->>'paso'), ' | ' order by cadena_pos) from asientos where id in (${lit(P[0])}, ${lit(P[1])})`)
       === `mano - - ${po1.po} salida | mano - - ${po1.po} llegada`);
  ok('E2E-14 la 1020 y la 1140 en cero; los pagos «en el depósito»', saldo('1020') === '0.00' && saldo('1140') === '0.00' && pagoPantalla(PI_1103) === 'en_payout' && pagoPantalla(PI_1101) === 'en_payout', [saldo('1020'), saldo('1140')]);

  // ---- E2E-15 Chase por Plaid: casa SOLO -------------------------------------
  const mov1 = await deposito('e2e-stripe-po1', po1.llegada, '11761.20');
  ok('E2E-15 el depósito STRIPE de 11,761.20 que trae Plaid casa solo con P2 (R1, automático, sin motivo)',
     /^R1 .*\|t\|sin motivo$/.test(casadoDe(po1.po)) && q(`select estado from movimientos_banco where id = ${lit(mov1)}`) === 'casado', casadoDe(po1.po));
  ok('E2E-15 v_stripe_payouts «casado» y los pagos «depositado»', q(`select estado_pantalla from v_stripe_payouts where po = ${lit(po1.po)}`) === 'casado' && pagoPantalla(PI_1103) === 'depositado' && pagoPantalla(PI_1101) === 'depositado');

  // ---- E2E-11 ACH fallido en la 1104 -----------------------------------------
  r = await crearEnlace('1104');
  p = await sim('/__pagar', { plink: r.j.enlace.plink, medio: 'ach' });
  const PI_1104A = p.pi;
  await mandar(p.eventos, ['checkout.session.completed', 'payment_intent.processing']);
  const fallo1104 = await sim('/__fallar', { pi: PI_1104A, codigo: 'insufficient_funds' });
  await mandar(fallo1104.eventos, ['payment_intent.payment_failed', 'checkout.session.async_payment_failed']);
  ok('E2E-11 ACH con fondos insuficientes: «fallido», nada en el libro, aviso grave',
     pago(PI_1104A, `estado || '|' || en_libro`) === 'fallido|0.00' && q(`select count(*) from stripe_pago_libro l join stripe_pagos s on s.id = l.pago_id where s.pi = ${lit(PI_1104A)}`) === '0'
     && q(`select nivel from stripe_avisos where clave = ${lit(`pago:${PI_1104A}:fallido`)}`) === 'bad');
  r = await crearEnlace('1104');
  const enlace1104b = r.j?.enlace;
  ok('E2E-11 crear_enlace otra vez → un enlace nuevo', r.estado === 200 && r.j.nuevo === true && enlace1104b?.plink !== undefined, r);

  // ---- E2E-13 disputa en la 1102 ---------------------------------------------------
  p = await sim('/__pagar', { plink: plink1102, medio: 'tarjeta' });
  const PI_1102 = p.pi;
  await mandar(p.eventos, ['checkout.session.completed', 'payment_intent.succeeded']);
  ok('E2E-13 la 1102 cobrada con tarjeta (3,200.50)', vivos(PI_1102) === '1|3200.50');
  const dA = await sim('/__disputa', { pi: PI_1102, fase: 'abrir' });
  await mandar(dA.eventos, ['charge.dispute.created', 'charge.dispute.funds_withdrawn']);
  ok('E2E-13 disputa con retiro: el cobro se devuelve, «en disputa», aviso grave con su fecha, la 1102 vuelve a deber',
     vivos(PI_1102) === '0|0' && pago(PI_1102) === 'en_disputa' && q(`select nivel from stripe_avisos where clave = ${lit(`pago:${PI_1102}:disputa:${dA.dp}`)}`) === 'bad'
     && q(`select saldo_cxc from v_stripe_facturas where factura_id = ${fid['1102']}`) === '3200.50', [vivos(PI_1102), pago(PI_1102)]);
  const dG = await sim('/__disputa', { pi: PI_1102, fase: 'ganar' });
  await mandar(dG.eventos, ['charge.dispute.closed', 'charge.dispute.funds_reinstated']);
  ok('E2E-13 ganada (reintegro): el cobro vuelve (llave :v1), «cobrado», aviso de que se ganó',
     vivos(PI_1102) === '1|3200.50' && pago(PI_1102) === 'cobrado' && q(`select count(*) from stripe_avisos where clave = ${lit(`pago:${PI_1102}:ganada:${dA.dp}`)}`) === '1'
     && q(`select llave_cliente from cobros where referencia = ${lit(PI_1102)} order by creado_el desc limit 1`) === `stripe:${PI_1102}:v1`);

  // ---- E2E-16 el aviso perdido, y el depósito de Chase que llega ANTES -------------
  p = await sim('/__pagar', { plink: enlace1104b.plink, medio: 'tarjeta' }); // sus avisos nunca se mandan
  const PI_1104B = p.pi;
  const po2 = await sim('/__payout', {});
  const mov2 = await deposito('e2e-stripe-po2', po2.llegada, (po2.monto / 100).toFixed(2));
  ok('E2E-16 el depósito de Chase llegó antes que el aviso: queda pendiente', q(`select estado from movimientos_banco where id = ${lit(mov2)}`) === 'pendiente');
  r = await webhook(de(po2.eventos, 'payout.paid'));
  ok('E2E-16 payout.paid con un cobro que p1 nunca vio: lo pide, lo registra y asienta el depósito', r.estado === 200 && vivos(PI_1104B) === '1|1000.00' && q(`select estado from stripe_payouts where po = ${lit(po2.po)}`) === 'asentado', r.j);
  ok('E2E-16 y casa en la llamada de casar que sigue al asiento (R1)', /^R1 .*\|t\|sin motivo$/.test(casadoDe(po2.po)) && q(`select estado from movimientos_banco where id = ${lit(mov2)}`) === 'casado', casadoDe(po2.po));
  ok('E2E-16 el ACH fallido (+ y − en el mismo depósito) deja 0, la 1020 y la 1140 en cero, sin cuadres rojos',
     saldo('1020') === '0.00' && saldo('1140') === '0.00' && cuadresRojos() === 'ninguno' && pagoPantalla(PI_1104B) === 'depositado' && pago(PI_1104A) === 'fallido', [saldo('1020'), saldo('1140'), cuadresRojos()]);

  // ---- E2E-16b el aviso del enlace llega antes que los del pago ---------------------
  const e1114 = (await crearEnlace('1114')).j?.enlace;
  const p1114 = await sim('/__pagar', { plink: e1114.plink, medio: 'ach' });
  await mandar(p1114.eventos, ['payment_link.updated']);
  r = await crearEnlace('1114');
  ok('E2E-16b payment_link.updated antes que el pago: el enlace «usado» y crear otro → 409 MX008 «ya se usó»',
     q(`select estado from stripe_enlaces where id = ${lit(e1114.id)}`) === 'usado' && r.estado === 409 && r.j.codigo === 'MX008' && /ya se usó/.test(r.j.error)
     && q(`select por_que_no from v_stripe_facturas where factura_id = ${fid['1114']}`) === 'pago en camino', r);
  r = await rutina();
  ok('E2E-16b la rutina busca el pago del enlace usado por sus sesiones: «en camino», sin otro enlace',
     r.estado === 200 && r.j.resumen?.enlaces_usados >= 1 && pago(p1114.pi) === 'en_camino'
     && q(`select count(*) from stripe_enlaces where factura_id = ${fid['1114']}`) === '1', r.j?.resumen);

  // ---- E2E-17 el barrido de la rutina -------------------------------------------
  const e1105 = (await crearEnlace('1105')).j.enlace;
  const p1105 = await sim('/__pagar', { plink: e1105.plink, medio: 'tarjeta' });
  await sim('/__no_entregado', { evts: p1105.eventos.map((e) => e.id) });
  const e1106 = (await crearEnlace('1106')).j.enlace;
  const p1106 = await sim('/__pagar', { plink: e1106.plink, medio: 'tarjeta' }); // «entregados» para Stripe, pero nunca llegaron
  const e1107 = (await crearEnlace('1107')).j.enlace;
  qErr(`begin; select set_config('request.jwt.claims', ${lit(JSON.stringify({ sub: dueno, role: 'authenticated' }))}, true), set_config('request.jwt.claim.sub', ${lit(dueno)}, true);
        select fn_factura_anular(${fid['1107']}, 'prueba e2e: se anuló con un enlace vivo'); commit;`);
  q(`update stripe_config set ultimo_barrido_completo_el = null where id = 1; delete from net._llamadas;`);
  q(`select fn_stripe_programado()`);
  const llamadaNet = JSON.parse(q(`select json_build_object('url', url, 'headers', headers, 'body', body) from net._llamadas order by id desc limit 1`));
  ok('E2E-17 fn_stripe_programado (pg_net) llama a la función con el secreto de Vault y {accion:barrer}',
     /\/functions\/v1\/stripe$/.test(llamadaNet.url) && llamadaNet.headers['x-mxp-rutina'] === RUTINA && llamadaNet.body.accion === 'barrer', { url: llamadaNet.url, body: llamadaNet.body });
  r = await llamar(llamadaNet.body, { rutina: llamadaNet.headers['x-mxp-rutina'] });
  ok('E2E-17 la rutina barre (completo)', r.estado === 200 && r.j.ok && r.j.resumen?.completo === true && !r.j.resumen.errores, r.j);
  ok('E2E-17 los avisos que Stripe no entregó los trae el barrido (por «barrido», hechos) y la 1105 cobra',
     vivos(p1105.pi) === '1|600.00' && q(`select string_agg(distinct por || ' ' || estado, ',') from stripe_eventos where id in (${p1105.eventos.map((e) => lit(e.id)).join(', ')})`) === 'barrido hecho',
     q(`select string_agg(id || ' ' || por || ' ' || estado, ',') from stripe_eventos where id in (${p1105.eventos.map((e) => lit(e.id)).join(', ')})`));
  ok('E2E-17 un enlace pagado sin ningún aviso se descubre por sus sesiones (la 1106 cobra)', vivos(p1106.pi) === '1|700.00' && q(`select estado from stripe_enlaces where id = ${lit(e1106.id)}`) === 'usado');
  const link1107 = (await sim('/__estado')).links.find((l) => l.id === e1107.plink);
  ok('E2E-17 el enlace de una factura anulada: desactivado en Stripe por la rutina, con aviso',
     q(`select estado || '|' || desactivado_por from stripe_enlaces where id = ${lit(e1107.id)}`) === 'desactivado|rutina' && link1107?.active === false
     && q(`select count(*) from stripe_avisos where clave = ${lit(`enlace:${e1107.id}`)}`) === '1', q(`select estado || '|' || coalesce(desactivado_por, '-') from stripe_enlaces where id = ${lit(e1107.id)}`));
  ok('E2E-17 la rutina queda anotada', q(`select (ultimo_barrido_el > now() - interval '2 minutes') and (ultimo_barrido_completo_el > now() - interval '2 minutes') from stripe_config`) === 't');

  // ---- E2E-18 Stripe caído durante un aviso; la base caída; un aviso atascado ----
  const e1108 = (await crearEnlace('1108')).j.enlace;
  const p1108 = await sim('/__pagar', { plink: e1108.plink, medio: 'tarjeta' });
  await sim('/__caer', { veces: 1000 });
  const evC = de(p1108.eventos, 'payment_intent.succeeded');
  r = await webhook(evC);
  await sim('/__caer', { veces: 0 });
  ok('E2E-18 Stripe caído durante el aviso: 200 a Stripe y el aviso queda «reintentar» (STRIPE_CAIDO)',
     r.estado === 200 && q(`select estado || '|' || codigo_error || '|' || (proximo_intento > now()) from stripe_eventos where id = ${lit(evC.id)}`) === 'reintentar|STRIPE_CAIDO|true' && vivos(p1108.pi) === '0|0', r);
  q(`update stripe_eventos set proximo_intento = now() - interval '1 minute' where id = ${lit(evC.id)}`);
  r = await rutina();
  ok('E2E-18 con Stripe de vuelta, la rutina lo deja «hecho», una sola vez', q(`select estado from stripe_eventos where id = ${lit(evC.id)}`) === 'hecho' && vivos(p1108.pi) === '1|800.00', r.j);
  const evB = { ...evC, id: 'evt_BASECAIDA0001' };
  if (atenderNode) {
    modulo.usarBaseDePruebas(basePsql(P_MUERTO));
    r = await webhook(evB);
    modulo.usarBaseDePruebas(basePsql(PGPORT));
  } else {
    r = await conEntorno({ MXP_DB_URL: `postgres://editor_sql:editor_sql@127.0.0.1:${P_MUERTO}/${BD}` }, (pt) => webhook(evB, { puerto: pt }));
  }
  ok('E2E-18 con la base caída: 500 a Stripe (que reintenta) y nada guardado', r.estado === 500 && q(`select count(*) from stripe_eventos where id = 'evt_BASECAIDA0001'`) === '0', r);
  q(`insert into stripe_eventos (id, tipo, objeto_tipo, objeto_id, livemode, creado_stripe, datos, por, recibido_el)
     values ('evt_ATASCADO0001', 'payment_intent.succeeded', 'payment_intent', ${lit(p1108.pi)}, false, now(), ${lit(JSON.stringify({ objeto: { id: p1108.pi, object: 'payment_intent' } }))}::jsonb, 'webhook', now() - interval '10 minutes')`);
  r = await rutina();
  ok('E2E-18 un aviso «recibido» de hace 10 minutos lo procesa la rutina', q(`select estado from stripe_eventos where id = 'evt_ATASCADO0001'`) === 'hecho' && vivos(p1108.pi) === '1|800.00', r.j);

  // ---- E2E-19 concurrencia ------------------------------------------------------
  const e1109 = (await crearEnlace('1109')).j.enlace;
  const p1109 = await sim('/__pagar', { plink: e1109.plink, medio: 'tarjeta' });
  const ev5 = de(p1109.eventos, 'payment_intent.succeeded');
  let rs = await Promise.all([1, 2, 3, 4, 5].map(() => webhook(ev5)));
  ok('E2E-19 el mismo aviso 5 veces a la vez → 1 cobro, veces = 5', rs.every((x) => x.estado === 200) && vivos(p1109.pi) === '1|900.00' && q(`select veces from stripe_eventos where id = ${lit(ev5.id)}`) === '5', rs.map((x) => x.j));
  const e1110 = (await crearEnlace('1110')).j.enlace;
  const p1110 = await sim('/__pagar', { plink: e1110.plink, medio: 'tarjeta' });
  rs = await Promise.all(['checkout.session.completed', 'payment_intent.succeeded', 'charge.succeeded'].map((t) => webhook(de(p1110.eventos, t))));
  ok('E2E-19 tres avisos distintos del mismo pago a la vez → 1 cobro', rs.every((x) => x.estado === 200) && vivos(p1110.pi) === '1|500.00', rs.map((x) => x.j));
  const poA = await sim('/__payout', {});
  const e1111 = (await crearEnlace('1111')).j.enlace;
  const p1111 = await sim('/__pagar', { plink: e1111.plink, medio: 'tarjeta' }); // sin avisos: lo trae su depósito
  const poB = await sim('/__payout', {});
  rs = await Promise.all([webhook(de(poA.eventos, 'payout.paid')), webhook(de(poB.eventos, 'payout.paid'))]);
  ok('E2E-19 dos depósitos a la vez: los dos asentados', rs.every((x) => x.estado === 200) && q(`select string_agg(estado, ',' order by po) from stripe_payouts where po in (${lit(poA.po)}, ${lit(poB.po)})`) === 'asentado,asentado' && vivos(p1111.pi) === '1|450.00', rs.map((x) => x.j));
  const e1112 = (await crearEnlace('1112')).j.enlace;
  await sim('/__pagar', { plink: e1112.plink, medio: 'tarjeta' });
  const poC = await sim('/__payout', {});
  // la sincronización de Plaid de la mañana (importar + «Casar» de la 1010) mientras se asienta otro depósito
  const plaidA = `\\set ON_ERROR_STOP 1\n${importarDeposito('e2e-stripe-poA', poA.llegada, (poA.monto / 100).toFixed(2))}\n${importarDeposito('e2e-stripe-poB', poB.llegada, (poB.monto / 100).toFixed(2))}\n`;
  const [wC, plaid] = await Promise.all([webhook(de(poC.eventos, 'payout.paid')), psqlAsync(plaidA)]);
  ok('E2E-19 un depósito que se asienta mientras corre la sincronización de Plaid: ninguno da 40P01',
     wC.estado === 200 && plaid.codigo === 0 && !/40P01|deadlock/i.test(plaid.error + JSON.stringify(wC.j) + salidaFn) && q(`select estado from stripe_payouts where po = ${lit(poC.po)}`) === 'asentado', { wC: wC.j, plaid: plaid.error.slice(0, 400) });
  await deposito('e2e-stripe-poC', poC.llegada, (poC.monto / 100).toFixed(2));
  r = await rutina(); // casa lo que Plaid trajo antes que el asiento
  ok('E2E-19 los tres depósitos casan con Chase', [poA, poB, poC].every((x) => /\|t\|sin motivo$/.test(casadoDe(x.po))), [poA, poB, poC].map((x) => casadoDe(x.po)));

  // ---- E2E-20 un depósito que falla después de pagado ---------------------------
  const e1113 = (await crearEnlace('1113')).j.enlace;
  const p1113 = await sim('/__pagar', { plink: e1113.plink, medio: 'tarjeta' });
  await mandar(p1113.eventos, ['payment_intent.succeeded']);
  const poD = await sim('/__payout', {});
  await mandar(poD.eventos, ['payout.paid']);
  const netoD = (poD.monto / 100).toFixed(2);
  const fD = await sim('/__payout_fallar', { po: poD.po, codigo: 'account_closed' });
  await mandar(fD.eventos, ['payout.failed']);
  const filaD = q(`select estado || '|' || (reverso_llegada is not null) || '|' || (asiento_vuelta is not null) from stripe_payouts where po = ${lit(poD.po)}`);
  ok('E2E-20 payout.failed después de pagado (sin casar): P2 reversado y P3; la 1140 en cero; la 1020 con lo que volvió a Stripe; aviso grave',
     filaD === 'fallido|true|true' && saldo('1140') === '0.00' && saldo('1020') === netoD && q(`select nivel from stripe_avisos where clave = ${lit(`payout:${poD.po}:fallido`)}`) === 'bad' && cuadresRojos() === 'ninguno', [filaD, saldo('1020'), saldo('1140'), cuadresRojos()]);
  const poE = await sim('/__payout', {});
  await mandar(poE.eventos, ['payout.paid']);
  ok('E2E-20 el depósito siguiente trae lo que volvió (payout_failure): asentado, la 1020 y la 1140 en cero',
     poE.monto === poD.monto && q(`select estado || '|' || vuelve from stripe_payouts where po = ${lit(poE.po)}`) === `asentado|${netoD}` && saldo('1020') === '0.00' && saldo('1140') === '0.00', [poE, saldo('1020')]);
  await deposito('e2e-stripe-poE', poE.llegada, netoD);
  ok('E2E-20 y casa con Chase', /\|t\|sin motivo$/.test(casadoDe(poE.po)), casadoDe(poE.po));

  // ---- E2E-21 lo que Edgar resuelve -------------------------------------------------
  const suelto = await sim('/__pago_suelto', { monto: 50000, medio: 'tarjeta' });
  await mandar(suelto.eventos, ['payment_intent.succeeded']);
  ok('E2E-21 un pago que no salió de un enlace: «por resolver», sin cobro, aviso grave', pago(suelto.pi) === 'revisar' && vivos(suelto.pi) === '0|0' && q(`select nivel from stripe_avisos where clave = ${lit(`pago:${suelto.pi}:revisar`)}`) === 'bad');
  const btRaro = await sim('/__bt', { tipo: 'reserve_transaction', monto: -2500 });
  const poF = await sim('/__payout', {});
  await mandar(poF.eventos, ['payout.paid']);
  ok('E2E-21 su depósito espera: «revisar» (un movimiento que la app no conoce) sin asiento',
     q(`select estado || '|' || (asiento_salida is null) from stripe_payouts where po = ${lit(poF.po)}`) === 'revisar|true' && /a qué cuenta va/.test(q(`select esperando::text from stripe_payouts where po = ${lit(poF.po)}`)));
  r = await llamar({ accion: 'resolver_pago', pi: suelto.pi, proyecto_id: 'casa-perez-k3m9' }, { jwt: D2 });
  ok('E2E-21 resolver_pago sin motivo → 400 FORMA', r.estado === 400 && r.j.codigo === 'FORMA', r);
  r = await llamar({ accion: 'resolver_pago', pi: suelto.pi, proyecto_id: 'casa-perez-k3m9', motivo: 'Anticipo de la obra pagado por fuera del enlace (prueba)' }, { jwt: D2 });
  ok('E2E-21 resolver_pago {proyecto_id, motivo}: anticipo de la obra, «cobrado», y vuelve a mirar su depósito', r.estado === 200 && r.j.estado === 'cobrado' && vivos(suelto.pi) === '1|500.00' && r.j.payouts?.some((x) => x.po === poF.po), r.j);
  r = await llamar({ accion: 'resolver_linea', po: poF.po, txn: btRaro.txn, cuenta: '1010', motivo: 'no' }, { jwt: D2 });
  ok('E2E-21 resolver_linea a la 1010 → 409 MX004', r.estado === 409 && r.j.codigo === 'MX004', r);
  r = await llamar({ accion: 'resolver_linea', po: poF.po, txn: btRaro.txn, cuenta: '6110', motivo: 'Reserva de Stripe (prueba)' }, { jwt: D2 });
  ok('E2E-21 resolver_linea a una cuenta de gasto: el depósito se asienta con esa línea', r.estado === 200 && r.j.estado === 'asentado'
     && / 6110 25\.00/.test(' ' + lineasDe(q(`select asiento_salida from stripe_payouts where po = ${lit(poF.po)}`))), [r.j, lineasDe(q(`select asiento_salida from stripe_payouts where po = ${lit(poF.po)}`))]);
  await deposito('e2e-stripe-poF', poF.llegada, (poF.monto / 100).toFixed(2));
  ok('E2E-21 la 1020 en cero y el depósito casado', saldo('1020') === '0.00' && /\|t\|/.test(casadoDe(poF.po)), [saldo('1020'), casadoDe(poF.po)]);

  // ---- E2E-22 las acciones de la pantalla ----------------------------------------------
  r = await crearEnlace('1103');
  const e1103b = r.j?.enlace;
  r = await llamar({ accion: 'desactivar_enlace', enlace: e1103b.id }, { jwt: D2 });
  ok('E2E-22 desactivar_enlace sin motivo → 400', r.estado === 400 && r.j.codigo === 'FORMA', r);
  r = await llamar({ accion: 'payout_fuera', po: po1.po }, { jwt: D2 });
  const r22b = await llamar({ accion: 'payout_fuera', po: po1.po, motivo: 'prueba e2e' }, { jwt: D2 });
  ok('E2E-22 payout_fuera («Ya está en el libro»): sin motivo → 400; a un depósito asentado → 409 MX008, sin tocarlo',
     r.estado === 400 && r.j.codigo === 'FORMA' && r22b.estado === 409 && r22b.j.codigo === 'MX008'
     && q(`select estado from stripe_payouts where po = ${lit(po1.po)}`) === 'asentado', [r.j, r22b.j]);
  antes = (await llamadasSim()).length;
  r = await llamar({ accion: 'desactivar_enlace', enlace: e1103b.id, motivo: 'el cliente pagará por cheque (prueba)' }, { jwt: D2 });
  ll = (await llamadasSim()).slice(antes);
  ok('E2E-22 desactivar_enlace: POST active=false (mxp-baja-<id>) y el enlace «desactivado»', r.estado === 200 && r.j.enlace?.estado === 'desactivado'
     && ll.some((l) => l.metodo === 'POST' && l.ruta === `/v1/payment_links/${e1103b.plink}` && l.cuerpo.active === 'false' && l.idem === `mxp-baja-${e1103b.id}`), r.j);
  const e1103c = (await crearEnlace('1103')).j.enlace;
  const p1103c = await sim('/__pagar', { plink: e1103c.plink, medio: 'tarjeta' });
  await mandar(p1103c.eventos, ['payment_intent.succeeded']);
  const poG = await sim('/__payout', {});
  await mandar(poG.eventos, ['payout.paid']);
  const P2G = q(`select asiento_llegada from stripe_payouts where po = ${lit(poG.po)}`);
  qErr(`begin; select set_config('request.jwt.claims', ${lit(JSON.stringify({ sub: dueno, role: 'authenticated' }))}, true), set_config('request.jwt.claim.sub', ${lit(dueno)}, true);
        select fn_reversar(${lit(P2G)}, 'prueba e2e: Edgar lo reversó a mano'); commit;`);
  ok('E2E-22 un asiento de Stripe reversado a mano pone en rojo el cuadre 25 (y el 23: la 1140 deja de estar en cero)', /(^| \| )25 /.test(cuadresRojos()), cuadresRojos());
  r = await llamar({ accion: 'reprocesar', po: poG.po, rehacer: true }, { jwt: D2 });
  ok('E2E-22 reprocesar {po, rehacer}: vuelve a postearlo y el control queda sin cuadres rojos', r.estado === 200 && r.j.estado === 'asentado' && cuadresRojos() === 'ninguno'
     && q(`select asiento_llegada <> ${lit(P2G)} from stripe_payouts where po = ${lit(poG.po)}`) === 't', [r.j, cuadresRojos()]);
  const netoG = (poG.monto / 100).toFixed(2);
  const g1 = await deposito('e2e-stripe-g1', poG.llegada, netoG, undefined, false);
  const manana = new Date(Date.parse(poG.llegada) + 86400_000).toISOString().slice(0, 10);
  await deposito('e2e-stripe-g2', manana, netoG);
  r = await llamar({ accion: 'casar_payout', po: poG.po }, { jwt: D2 });
  ok('E2E-22 casar_payout con dos depósitos iguales en la ventana: no casa solo', r.estado === 200 && r.j.casado === false && r.j.candidatos === 2, r.j);
  r = await llamar({ accion: 'casar_payout', po: poG.po, movimiento_id: g1 }, { jwt: D2 });
  ok('E2E-22 casar_payout con el movimiento elegido: casa con el motivo «Stripe p1: …»', r.estado === 200 && r.j.casado === true && /\|f\|Stripe p1: /.test(casadoDe(poG.po)), [r.j, casadoDe(poG.po)]);
  const aviso = q(`select id from v_stripe_avisos order by id limit 1`);
  r = await llamar({ accion: 'aviso_visto', aviso: Number(aviso) }, { jwt: D2 });
  ok('E2E-22 aviso_visto: sale de v_stripe_avisos', r.estado === 200 && q(`select count(*) from v_stripe_avisos where id = ${aviso}`) === '0' && q(`select visto_por from stripe_avisos where id = ${aviso}`) === dueno, r.j);
  r = await llamar({ accion: 'reprocesar', pi: PI_1103 }, { jwt: D2 });
  ok('E2E-22 reprocesar {pi}: vuelve a mirar el pago, sin cambios', r.estado === 200 && r.j.estado === 'cobrado' && vivos(PI_1103) === '1|7000.00', r.j);
  r = await llamar({ accion: 'reprocesar', evento: de(p1110.eventos, 'checkout.session.completed').id }, { jwt: D2 });
  ok('E2E-22 reprocesar {evento}: lo pide a Stripe, lo guarda y lo procesa', r.estado === 200 && r.j.evento?.estado === 'hecho' && vivos(p1110.pi) === '1|500.00', r.j);
  r = await llamar({ accion: 'barrer' }, { jwt: D2 });
  ok('E2E-22 barrer desde la pantalla', r.estado === 200 && r.j.resumen?.por === 'pantalla', r.j);

  // ---- E2E-23 llave de prueba en una base que no la acepta ---------------------------------
  q(`update stripe_config set acepta_prueba = false where id = 1`);
  r = await webhook({ ...de(p1103c.eventos, 'payment_intent.succeeded'), id: 'evt_MODO0001' });
  const r23 = await crearEnlace('1104');
  q(`update stripe_config set acepta_prueba = true where id = 1`);
  ok('E2E-23 sin acepta_prueba: el aviso queda «ignorado» con su aviso para Edgar', r.estado === 200 && q(`select estado from stripe_eventos where id = 'evt_MODO0001'`) === 'ignorado' && q(`select count(*) from stripe_avisos where clave = 'modo'`) === '1', r);
  ok('E2E-23 y crear_enlace → 409 con la pista PRUEBA', r23.estado === 409 && r23.j.codigo === 'MX008' && r23.j.pista === 'PRUEBA', r23);

  // ---- E2E-24 el cierre ------------------------------------------------------------------------
  if (saldo('1020') !== '0.00') {
    const poZ = await sim('/__payout', {});
    await mandar(poZ.eventos, ['payout.paid']);
    await deposito('e2e-stripe-poZ', poZ.llegada, (poZ.monto / 100).toFixed(2));
  }
  ok('E2E-24 la 1020 (puente) y la 1140 (paso) en cero', saldo('1020') === '0.00' && saldo('1140') === '0.00', [saldo('1020'), saldo('1140')]);
  ok('E2E-24 cada depósito asentado casó con Chase (o es el fallido)', q(`select count(*) from v_stripe_payouts where estado_pantalla not in ('casado', 'fallido')`) === '0', q(`select string_agg(po || ' ' || estado_pantalla, ', ') from v_stripe_payouts`));
  ok('E2E-24 el control de p1 sin cuadres rojos', cuadresRojos() === 'ninguno', cuadresRojos());
  const rojos = q(`select coalesce(string_agg(x, '; '), 'ninguno') from (select 'c2 ' || control as x from fn_verificar_cadena() where not ok union all select 'c6 ' || vista from fn_banco_control('hoy') where not ok union all select 'c4 ' || vista from fn_estados_control('hoy') where not ok and vista <> 'cuadre: apertura en el libro' union all select 'c3 ' || control from fn_puentes_verificar() where not ok) r`);
  ok('E2E-24 fn_verificar_cadena, fn_banco_control(hoy), fn_puentes_verificar y fn_estados_control(hoy) sin rojos (salvo la apertura de fábrica)', rojos === 'ninguno', rojos);
  const enApi = q(`select coalesce(string_agg(p.proname || ' → ' || g, ', '), 'ninguna') from pg_proc p, unnest(array['anon','authenticated','service_role']) g where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\\_stripe%' and (has_function_privilege(g, p.oid, 'execute') or p.prosecdef)`);
  ok('E2E-24 ninguna fn_stripe_* en la API ni SECURITY DEFINER', enApi === 'ninguna', enApi);
  const sim1 = JSON.stringify(await sim('/__estado')) + JSON.stringify(await sim('/__eventos'));
  const tablas = q(`select coalesce((select string_agg(x::text, '') from stripe_eventos x), '') || coalesce((select string_agg(x::text, '') from stripe_config x), '') || coalesce((select string_agg(x::text, '') from stripe_avisos x), '') || coalesce((select string_agg(x::text, '') from stripe_pagos x), '')`);
  const dondeLlaves = [['respuestas', respuestas.join('\n')], ['salida de la función', salidaFn], ['simulador', sim1], ['tablas stripe_*', tablas]]
    .flatMap(([n, s]) => [LLAVE, WHSEC, RUTINA].filter((k) => s.includes(k)).map((k) => `${n}: ${k.slice(0, 8)}…`));
  ok('E2E-24 ninguna llave (rk_test_prueba, whsec_prueba, el secreto de la rutina) en las respuestas, la salida, el simulador ni las tablas', dondeLlaves.length === 0, dondeLlaves);
  const personales = /cliente@ejemplo\.com|Cliente Ejemplo|""last4""|""routing_number""|""billing_details""|""customer_details""|""receipt_email""|""email""/;
  ok('E2E-24 ningún dato personal guardado (correo, nombre, últimos 4, ruta del banco)', !personales.test(tablas), tablas.match(new RegExp('.{60}(' + personales.source + ').{20}'))?.[0]);
} catch (e) {
  ok('la prueba corrió entera', false, (e && e.stack) || String(e));
}
limpiarHijos();
const malas = resultados.filter((x) => !x.ok).length;
if (malas && salidaFn.trim()) console.log('--- lo que escribió la función ---\n' + salidaFn.slice(-3000));
console.log(`STRIPE-E2E (${CON_DENO ? 'deno' : 'node'}) total=${resultados.length} ok=${resultados.length - malas} fallan=${malas}${process.env.CONSERVAR ? ` (la base ${BD} se queda)` : ''}`);
if (!process.env.CONSERVAR && !process.env.SIN_CONSTRUIR) { try { execFileSync('./correr.sh', ['--borrar', BD], { cwd: AQUI, env: { ...process.env, PGHOST: '127.0.0.1', PGPORT }, stdio: 'ignore' }); } catch { /* queda */ } }
process.exit(malas ? 1 : 0);
