/* plaid-e2e.mjs — la función de borde `plaid` de punta a punta, sin internet:
   un Plaid simulado (plaid-simulado.mjs), la función corriendo en Deno contra
   el banco de pruebas (c1..c6 + c7) y las comprobaciones de lo que pasa en la
   base: conectar, el freno de las cuentas sin fijar, sincronizar (dos páginas,
   una pendiente que no entra, los saldos), la ronda 2 por la rutina (una
   quitada, una modificada, dos nuevas), el error del banco, volver a
   conectar, desconectar (el token fuera de Vault), el webhook y quién puede
   llamar. Deja la base si CONSERVAR=1.
   Uso: node pruebas/conta/plaid-e2e.mjs [bd=plaid17] [puerto_pg=5433]
        SIN_CONSTRUIR=1 usa la base que ya existe (con c7 y la tarjeta ····1007).
   Necesita deno (DENO, o /opt/node22/bin/deno) con npm:postgres y
   npm:@supabase/supabase-js ya en su caché (DENO_DIR). */
import { spawn, execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const R = path.resolve(AQUI, '../..');
const BD = process.argv[2] || 'plaid17';
const PGPORT = process.argv[3] || process.env.PGPORT || '5433';
const PG_ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT, PGPASSWORD: 'editor_sql' };
const DENO = process.env.DENO || '/opt/node22/bin/deno';
const P_SIM = 8890, P_FN = 8891;
const SECRETO = randomBytes(32).toString('hex');
const DUENO_ID = () => q(`select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1`);
const EQUIPO_ID = () => q(`select id from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1`);

const t0 = Date.now();
const log = (m) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
const resultados = [];
function ok(nombre, cond, detalle) {
  resultados.push({ nombre, ok: !!cond });
  console.log(`${cond ? ' ok ' : 'MAL '} ${nombre}${cond ? '' : ' — ' + String(typeof detalle === 'string' ? detalle : JSON.stringify(detalle ?? '')).slice(0, 600)}`);
}
function q(sql) {
  return execFileSync('psql', ['-X', '-At', '-F', '|', '-U', 'editor_sql', '-d', BD, '-c', sql], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'] }).toString().trim();
}
function qDueno(id, sql) { // una llamada como el dueño por la API (rol authenticated + sus claims), en una transacción
  const claims = JSON.stringify({ sub: id, role: 'authenticated' });
  return q(`begin; select set_config('request.jwt.claims', '${claims}', true); select set_config('request.jwt.claim.sub', '${id}', true); set local role authenticated; ${sql}; commit;`);
}
const b64u = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (sub) => `${b64u({ alg: 'none', typ: 'JWT' })}.${b64u({ sub, role: 'authenticated', exp: 4102444800 })}.firma`;
async function llamar(cuerpo, { jwt: tok, rutina } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (tok) headers.Authorization = `Bearer ${tok}`;
  if (rutina !== undefined) headers['x-mxp-rutina'] = rutina;
  const r = await fetch(`http://127.0.0.1:${P_FN}/`, { method: 'POST', headers, body: JSON.stringify(cuerpo) });
  let j = null; try { j = await r.json(); } catch { /* sin json */ }
  return { estado: r.status, j };
}
const sim = async (ruta, cuerpo = {}) => (await fetch(`http://127.0.0.1:${P_SIM}${ruta}`, { method: 'POST', body: JSON.stringify(cuerpo) })).json();
const sumar = (res, k) => (res?.conexion?.ultimo_resultado?.importado ?? []).reduce((s, x) => s + Number(x[k] || 0), 0);

// ---- 1. la base ----------------------------------------------------------
if (!process.env.SIN_CONSTRUIR) {
  log(`construyo ${BD} en el puerto ${PGPORT} (c1..c6, unos 30 s)…`);
  const archivos = ['03-storage-simulacro.sql', ...['c1-plan-de-cuentas', 'c2-libro', 'c3-puentes', 'c4-estados', 'c6-banco'].map(f => `../../docs/conta/${f}.sql`)];
  try {
    execFileSync('./correr.sh', [BD, ...archivos], { cwd: AQUI, env: { ...process.env, PGHOST: '127.0.0.1', PGPORT }, stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) { console.error('correr.sh falló:\n' + (e.stdout?.toString().split('\n').slice(-15).join('\n') ?? '') + (e.stderr?.toString().slice(-2000) ?? '')); process.exit(2); }
  const su = process.env.BANCO_SU ? process.env.BANCO_SU.split(' ') : (process.getuid && process.getuid() === 0 ? ['runuser', '-u', 'postgres', '--', 'psql'] : ['psql', '-U', 'postgres']);
  const envSu = { ...process.env }; delete envSu.PGHOST;
  execFileSync(su[0], [...su.slice(1), '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-p', PGPORT, '-d', BD, '-f', path.join(R, 'pruebas/seguridad/00-vault-shim.sql')], { env: envSu, stdio: ['ignore', 'pipe', 'pipe'] });
  execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-f', path.join(R, 'docs/conta/c7-plaid.sql')], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'] });
  q(`select fn_tarjeta_alta('1007', '2100-2013', 'Amex Business Gold (prueba Plaid)')`);
  log('base lista');
}
const dueno = DUENO_ID(), equipo = EQUIPO_ID();
ok('hay dueño y equipo en la base', dueno && equipo, { dueno, equipo });

// ---- 2. el Plaid simulado y la función -------------------------------------
const hijos = [];
const simulador = spawn(process.execPath, [path.join(AQUI, 'plaid-simulado.mjs'), String(P_SIM)], { stdio: ['ignore', 'pipe', 'inherit'] }); hijos.push(simulador);
await new Promise((res) => simulador.stdout.once('data', res));
const fn = spawn(DENO, ['run', '--quiet', '-A', path.join(R, 'supabase/functions/plaid/index.ts')], {
  stdio: ['ignore', 'pipe', 'pipe'],
  env: {
    ...process.env, PLAID_CLIENT_ID: 'prueba-client', PLAID_SECRET: 'prueba-secret', PLAID_ENV: 'sandbox', PLAID_BASE_URL: `http://127.0.0.1:${P_SIM}`,
    PLAID_RUTINA_SECRETO: SECRETO, PLAID_REDIRECT_URI: 'https://edgararboleya-rgb.github.io/max-power-panel/', PLAID_DIAS: '45',
    MXP_BANCO_PG: `postgres://editor_sql:editor_sql@127.0.0.1:${PGPORT}/${BD}`, MXP_PUERTO: String(P_FN), SUPABASE_URL: `http://127.0.0.1:${P_FN}`,
  },
});
hijos.push(fn);
let salidaFn = '';
fn.stdout.on('data', d => { salidaFn += d; }); fn.stderr.on('data', d => { salidaFn += d; });
const limpiar = () => { for (const h of hijos) { try { h.kill(); } catch { /* ya */ } } };
process.on('exit', limpiar);
let salud = null;
for (let i = 0; i < 120 && !salud; i++) {
  try { const r = await fetch(`http://127.0.0.1:${P_FN}/?paso=salud`); if (r.ok) salud = await r.json(); } catch { /* todavía no */ }
  if (!salud) await new Promise(r => setTimeout(r, 500));
}
ok('la función arranca y contesta salud', salud && salud.ok && salud.entorno === 'sandbox' && salud.llaves && salud.rutina && salud.banco_de_pruebas, salud ?? salidaFn.slice(-800));
if (!salud) { console.error(salidaFn.slice(-3000)); limpiar(); process.exit(2); }

try {
  const D = jwt(dueno), E = jwt(equipo);
  // ---- 3. quién puede -----------------------------------------------------
  let r = await llamar({ accion: 'link_token' });
  ok('sin sesión → 401', r.estado === 401 && r.j?.ok === false, r);
  r = await llamar({ accion: 'link_token' }, { jwt: E });
  ok('el equipo → 403', r.estado === 403, r);
  r = await llamar({ accion: 'sincronizar_todo' }, { rutina: 'x'.repeat(64) });
  ok('la rutina con otro secreto → 401', r.estado === 401, r);
  r = await llamar({ accion: 'nada' }, { jwt: D });
  ok('acción desconocida → 400', r.estado === 400, r);
  r = await llamar({ accion: 'estado' }, { jwt: D });
  ok('estado (dueño): sin conexiones', r.estado === 200 && r.j.ok && Array.isArray(r.j.conexiones) && r.j.conexiones.length === 0 && r.j.redirect === true, r);

  // ---- 4. conectar ----------------------------------------------------------
  r = await llamar({ accion: 'link_token' }, { jwt: D });
  ok('link_token nuevo', r.estado === 200 && /^link-sandbox-/.test(r.j.link_token) && r.j.reconexion === false, r);
  let est = await sim('/__estado');
  let pedido = est.llamadas.filter(l => l.ruta === '/link/token/create').pop()?.cuerpo;
  ok('link_token pide transactions, 45 días, redirect, webhook y el dueño como usuario',
     pedido && pedido.products?.[0] === 'transactions' && pedido.transactions?.days_requested === 45 && pedido.redirect_uri === 'https://edgararboleya-rgb.github.io/max-power-panel/'
       && /\/functions\/v1\/plaid$/.test(pedido.webhook) && pedido.user?.client_user_id === dueno && pedido.language === 'es', pedido);
  r = await llamar({ accion: 'canjear', public_token: 'malo' }, { jwt: D });
  ok('canjear con un public_token malo → 502 INVALID_PUBLIC_TOKEN', r.estado === 502 && r.j.codigo === 'INVALID_PUBLIC_TOKEN', r);
  r = await llamar({ accion: 'canjear', public_token: 'public-sandbox-abc', metadata: { institution: { name: 'Platypus Bank', institution_id: 'ins_109508' } } }, { jwt: D });
  const cx = r.j?.conexion;
  const ctas = cx?.cuentas ?? [];
  const tarjeta = ctas.find(c => c.account_id === 'acc-tarjeta-1'), corriente = ctas.find(c => c.account_id === 'acc-corriente-1');
  ok('canjear: la conexión queda activa con sus dos cuentas', r.estado === 200 && cx?.estado === 'activa' && cx.item_id === 'item-sim-1' && cx.institucion === 'Platypus Bank' && ctas.length === 2 && cx.tiene_token === true, r);
  ok('la tarjeta ····1007 se propone a 2100-2013; la corriente queda sin fijar', tarjeta?.cuenta === '2100-2013' && /dada de alta/.test(tarjeta?.propuesta ?? '') && corriente && corriente.cuenta === undefined && cx?.cuentas_sin_fijar === 1, ctas);
  ok('el token está en Vault y no en la tabla', q(`select count(*) from vault.secrets where name = 'plaid_item_item-sim-1'`) === '1' && q(`select count(*) from plaid_conexiones where cuentas::text like '%access-sandbox%' or coalesce(ultimo_resultado::text, '') like '%access-sandbox%'`) === '0');

  // ---- 5. el freno: sin fijar no se sincroniza ---------------------------------
  const llamadasAntes = (await sim('/__estado')).llamadas.filter(l => l.ruta === '/transactions/sync').length;
  r = await llamar({ accion: 'sincronizar', item_id: 'item-sim-1' }, { jwt: D });
  ok('sincronizar con la corriente sin fijar → 409 SIN_FIJAR y Plaid no se toca', r.estado === 409 && r.j.codigo === 'SIN_FIJAR' && /4392/.test(r.j.error) && (await sim('/__estado')).llamadas.filter(l => l.ruta === '/transactions/sync').length === llamadasAntes, r);
  ok('el cursor sigue nulo y la conexión sin error', q(`select coalesce(cursor, 'nulo') || '|' || coalesce(ultimo_error, 'sin error') || '|' || estado from plaid_conexiones where item_id = 'item-sim-1'`) === 'nulo|sin error|activa');
  const fij = qDueno(dueno, `select fn_plaid_cuenta_fijar('item-sim-1', 'acc-corriente-1', '1010') ->> 'cuentas_sin_fijar'`);
  ok('el dueño fija la corriente a 1010 (por la API, rol authenticated)', fij.split('\n').includes('0'), fij);

  // ---- 6. la primera sincronización -------------------------------------------
  r = await llamar({ accion: 'sincronizar', item_id: 'item-sim-1' }, { jwt: D });
  ok('sincronizar: dos páginas, 8 agregadas, 2 lotes', r.estado === 200 && r.j.ok && r.j.paginas === 2 && r.j.agregadas === 8 && r.j.lotes === 2, r.j);
  ok('entraron 7 (la pendiente queda fuera) y el cursor avanzó', sumar(r.j, 'filas_nuevas') === 7 && sumar(r.j, 'filas_fuera') === 1 && r.j.conexion?.cursor === 'cursor-r1-fin', r.j?.conexion?.ultimo_resultado);
  const movs = q(`select count(*) || '|' || count(distinct a.importado_por) || '|' || min(a.importado_por::text) || '|' || string_agg(distinct a.importado_rol, ',') from movimientos_banco m join archivos_banco a on a.id = m.archivo_id where m.origen = 'plaid'`);
  ok('7 movimientos de origen plaid, importados en nombre del dueño con rol service_role', movs === `7|1|${dueno}|service_role`, movs);
  ok('2 archivos «Plaid · Platypus Bank ····…» con su saldo', q(`select count(*) || '|' || string_agg(cuenta || '=' || saldo::text, ',' order by cuenta) from archivos_banco where formato = 'plaid' and nombre like 'Plaid · Platypus Bank ····%'`) === '2|1010=15979.78,2100-2013=-15420.33');
  const saldos = r.j.conexion?.ultimo_resultado?.saldos ?? {};
  ok('los saldos de Plaid quedan en el resultado (1010 y 2100-2013)', saldos['1010']?.saldo === 15979.78 && saldos['2100-2013']?.saldo === 15420.33 && saldos['2100-2013']?.mask === '1007', saldos);
  ok('v_banco_saldos ve el saldo del banco por Plaid', q(`select saldo_banco::text from v_banco_saldos where cuenta = '1010'`) === '15979.78');
  ok('el pago de la Amex desde Chase se casó como transferencia (R3) o espera en la bandeja', ['0', '2'].includes(q(`select count(*) from movimientos_banco where origen = 'plaid' and abs(monto) = 1000 and estado = 'casado'`)));
  const vista = qDueno(dueno, `select estado || '|' || cuentas_sin_fijar || '|' || sincronizada_alguna_vez from v_plaid_conexiones where item_id = 'item-sim-1'`);
  ok('v_plaid_conexiones (dueño): activa, 0 sin fijar, sincronizada', vista.split('\n').includes('activa|0|true'), vista);
  r = await llamar({ accion: 'sincronizar', item_id: 'item-sim-1' }, { jwt: D });
  ok('sincronizar otra vez sin novedades: 0 agregadas, 0 lotes, mismo cursor', r.estado === 200 && r.j.agregadas === 0 && r.j.lotes === 0 && r.j.conexion?.cursor === 'cursor-r1-fin', r.j);

  // ---- 7. la ronda 2 por la rutina (el cron) --------------------------------------
  await sim('/__ronda2');
  r = await llamar({ accion: 'sincronizar_todo' }, { rutina: SECRETO });
  const r1 = r.j?.resultados?.[0];
  ok('la rutina sincroniza todo: 2 agregadas, 1 modificada, 1 quitada', r.estado === 200 && r.j.ok && r.j.conexiones === 1 && r1?.ok && r1.agregadas === 2 && r1.modificadas === 1 && r1.quitadas === 1 && r1.conexion?.cursor === 'cursor-r2-fin', r.j);
  const n2 = q(`select count(*) from movimientos_banco where origen = 'plaid'`);
  const dup = q(`select count(*) from movimientos_banco where origen = 'plaid' and posible_duplicado_de is not null`);
  ok('las 2 nuevas entraron y la modificada (45.10 → 45.12) entró como posible duplicado para que Edgar decida', n2 === '10' && dup === '1' && sumar(r1, 'duplicados_posibles') === 1, { n2, dup, importado: r1?.conexion?.ultimo_resultado?.importado });
  const avisoQuitada = JSON.stringify(r1?.conexion?.ultimo_resultado?.importado ?? []);
  ok('la quitada (la pendiente, que nunca entró) solo deja su aviso', /no había entrado/.test(avisoQuitada), avisoQuitada.slice(0, 300));
  ok('ultimo_resultado dice por qué (rutina) y cuántas páginas', r1?.conexion?.ultimo_resultado?.por_que === 'rutina' && r1?.conexion?.ultimo_resultado?.paginas === 1, r1?.conexion?.ultimo_resultado);

  // ---- 8. el banco falla (hay que volver a conectar) -------------------------------
  await sim('/__fallar_sync', { si: true });
  r = await llamar({ accion: 'sincronizar', item_id: 'item-sim-1' }, { jwt: D });
  ok('el error del banco → 502, ITEM_LOGIN_REQUIRED, hay que reconectar', r.estado === 502 && r.j.ok === false && r.j.codigo === 'ITEM_LOGIN_REQUIRED' && r.j.hay_que_reconectar === true, r.j);
  const filaErr = q(`select estado || '|' || left(ultimo_error, 40) || '|' || cursor from plaid_conexiones where item_id = 'item-sim-1'`);
  ok('la conexión queda en error con el mensaje, y el cursor no se movió', filaErr === 'error|Plaid /transactions/sync: ITEM_LOGIN_REQ|cursor-r2-fin', filaErr);
  await sim('/__fallar_sync', { si: false });
  r = await llamar({ accion: 'link_token', item_id: 'item-sim-1' }, { jwt: D });
  pedido = (await sim('/__estado')).llamadas.filter(l => l.ruta === '/link/token/create').pop()?.cuerpo;
  ok('link_token de reconexión: lleva el access_token y no pide productos', r.estado === 200 && r.j.reconexion === true && pedido?.access_token === '***' && !pedido.products, pedido);
  r = await llamar({ accion: 'sincronizar', item_id: 'item-sim-1' }, { jwt: D });
  ok('al volver a sincronizar bien, el error se limpia', r.estado === 200 && r.j.ok && r.j.conexion?.estado === 'activa' && r.j.conexion?.ultimo_error == null, r.j?.conexion);

  // ---- 9. el webhook -------------------------------------------------------------
  r = await llamar({ webhook_type: 'TRANSACTIONS', webhook_code: 'SYNC_UPDATES_AVAILABLE', item_id: 'item-sim-1', new_transactions: 0 });
  ok('webhook TRANSACTIONS: sincroniza esa conexión (sin sesión)', r.estado === 200 && r.j.ok && r.j.item_id === 'item-sim-1' && r.j.conexion?.ultimo_resultado?.por_que === 'webhook SYNC_UPDATES_AVAILABLE', r.j);
  r = await llamar({ webhook_type: 'TRANSACTIONS', webhook_code: 'SYNC_UPDATES_AVAILABLE', item_id: 'item-desconocido' });
  ok('webhook de un item desconocido: se ignora con 200', r.estado === 200 && r.j.ignorado === 'conexión desconocida', r.j);
  r = await llamar({ webhook_type: 'ITEM', webhook_code: 'ERROR', item_id: 'item-sim-1', error: { error_code: 'ITEM_LOGIN_REQUIRED', error_message: 'the login details of this item have changed' } });
  ok('webhook ITEM/ERROR: se anota el error', r.estado === 200 && /ITEM_LOGIN_REQUIRED/.test(r.j.anotado ?? '') && q(`select estado from plaid_conexiones where item_id = 'item-sim-1'`) === 'error', r.j);

  // ---- 10. desconectar ---------------------------------------------------------------
  r = await llamar({ accion: 'desconectar', item_id: 'item-sim-1', motivo: 'prueba de punta a punta' }, { jwt: D });
  est = await sim('/__estado');
  ok('desconectar: Plaid recibe /item/remove, la conexión queda desconectada con su motivo', r.estado === 200 && r.j.ok && r.j.conexion?.estado === 'desconectada' && r.j.conexion?.desconectada_motivo === 'prueba de punta a punta' && est.items.length === 0 && est.llamadas.some(l => l.ruta === '/item/remove'), r.j);
  ok('el token salió de Vault', q(`select count(*) from vault.secrets where name like 'plaid_item_%'`) === '0' && r.j.conexion?.tiene_token === false);
  r = await llamar({ accion: 'sincronizar', item_id: 'item-sim-1' }, { jwt: D });
  ok('sincronizar una desconectada → 409', r.estado === 409, r.j);
  r = await llamar({ webhook_type: 'TRANSACTIONS', webhook_code: 'DEFAULT_UPDATE', item_id: 'item-sim-1' });
  ok('webhook de una desconectada: se ignora', r.estado === 200 && r.j.ignorado === 'desconectada', r.j);
  r = await llamar({ accion: 'sincronizar_todo' }, { rutina: SECRETO });
  ok('la rutina sin conexiones vivas: 0', r.estado === 200 && r.j.conexiones === 0, r.j);
  ok('los movimientos importados siguen en el libro del banco (desconectar no borra nada)', q(`select count(*) from movimientos_banco where origen = 'plaid'`) === '10');
  ok('las llaves de Plaid nunca salieron por la función', !JSON.stringify(resultados).includes('prueba-secret') && !salidaFn.includes('prueba-secret') && !salidaFn.includes('access-sandbox'));
} catch (e) {
  ok('la prueba corrió entera', false, (e && e.stack) || String(e));
  console.error(salidaFn.slice(-2000));
}
limpiar();
const malas = resultados.filter(x => !x.ok).length;
if (malas && salidaFn.trim()) console.log('--- lo que escribió la función ---\n' + salidaFn.slice(-3000));
console.log(`PLAID-E2E total=${resultados.length} ok=${resultados.length - malas} fallan=${malas}${process.env.CONSERVAR ? ` (la base ${BD} se queda)` : ''}`);
if (!process.env.CONSERVAR && !process.env.SIN_CONSTRUIR) { try { execFileSync('./correr.sh', ['--borrar', BD], { cwd: AQUI, env: { ...process.env, PGHOST: '127.0.0.1', PGPORT }, stdio: 'ignore' }); } catch { /* queda */ } }
process.exit(malas ? 1 : 0);
