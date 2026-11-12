/* facturas-e2e.mjs — la función de borde `facturas` (f10, c11) de punta a
   punta, sin internet: la función contra el banco de pruebas, por la API
   como en Supabase (una PostgREST, un Storage y un Auth de mentira, en
   127.0.0.1, que corren cada llamada EN LA BASE como `authenticated` con los
   claims del JWT de quien llama: las RLS, es_dueno() y las funciones de c11
   son las de verdad), la función `stripe` de p1 de verdad (importada aquí,
   con su base por psql), el Stripe simulado de p1 (stripe-simulado.mjs) con
   un portero delante que sabe restringir los métodos de un Payment Link, y un
   Resend de mentira. Lo que se comprueba:
     · quién puede (sin sesión, sesión mala, sin el código del teléfono, el
       equipo, una acción que no existe, sin documento) y «salud»;
     · el PDF de una factura emitida: el enlace de p1 pedido por la función
       stripe y dejado SOLO por cuenta de banco en Stripe antes de imprimirlo,
       la base que lo da por bueno, el archivo subido al bucket «facturas»
       (con su RLS), registrado con su sha256 y su tamaño, lo que dice el PDF
       por dentro (pdftotext: el número, las fechas, la obra, la retención
       descontada, el total, How to pay, el enlace) y su huella en los
       metadatos; otra vez: el MISMO archivo (no se registra dos veces ni se
       pide otro enlace);
     · el correo: lo que recibe Resend (de, para, copia a Edgar, responder-a,
       asunto, el PDF adjunto que es el registrado, el botón de pago), el
       envío apuntado en la factura y en la tabla correos; el reenvío; Resend
       caído; el correo que sale y no se apunta (y apuntarlo después con su id
       de Resend, sin volver a mandarlo); correos sin permiso (avisa y sigue);
     · Stripe que no deja restringir el enlace (y el PDF sin enlace) y la
       llave sin permiso; el enlace desfasado por un cobro parcial (se pide
       otro y el PDF nuevo es otra versión); la factura de la retención (sin
       enlace); una anulada (ni PDF ni correo); un borrador (no);
     · la función también en Deno (si hay Deno: el binario de DENO, o
       /opt/node22/bin/deno): el mismo PDF, byte a byte, que en Node;
     · ninguna llave en ninguna respuesta.
   Al final deja los PDF y sus páginas en PNG (pdftoppm) en FOTOS_DIR (o en
   el temporal del sistema) para mirarlos.

   Uso: node pruebas/conta/facturas-e2e.mjs [bd=u10e] [plantilla=g9a]
        La base se crea desde la plantilla (la cadena c1..c10 + p1 + s1 ya
        pegada) y se borra al terminar (CONSERVAR=1 la deja). Necesita el
        banco levantado (pruebas/conta/pg17.sh), pdftotext/pdftoppm (poppler)
        y pdf-lib + qrcode: con LIBS=<carpeta con node_modules> los toma de
        ahí; si no, los instala con npm en el temporal del sistema.
        F36 (la función EN DENO, con npm:pdf-lib y npm:qrcode del registro):
        DENO=<ruta del binario de deno> y, detrás de un proxy con su propia
        autoridad, DENO_CERT=<su certificado> (DENO_DIR=<carpeta> para no
        bajarlas cada vez); sin Deno, F36 sale «omitida». */
import { spawn, execFileSync } from 'node:child_process';
import http from 'node:http';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import os from 'node:os';
import { crearSimulador, leerFormulario } from './stripe-simulado.mjs';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const R = path.resolve(AQUI, '../..');
const BD = process.argv[2] || 'u10e';
const PLANTILLA = process.argv[3] || 'g9a';
const PGPORT = process.env.PGPORT || '5433';
const PG_ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT, PGPASSWORD: 'editor_sql' };
const P_GW = 8971, P_SIM = 8972, P_STRIPE = 8973, P_RESEND = 8974, P_DENO = 8975;
const LLAVE = 'rk_test_prueba', RESEND_LLAVE = 're_test_llave_de_prueba_u10_0000000000';
const FOTOS = process.env.FOTOS_DIR || path.join(os.tmpdir(), 'mxp-facturas-fotos');
mkdirSync(FOTOS, { recursive: true });
const DENO = process.env.DENO || '/opt/node22/bin/deno';
const HOY = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());

const t0 = Date.now();
const log = (m) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
const resultados = [], respuestas = [];
function ok(nombre, cond, detalle) {
  resultados.push({ nombre, ok: !!cond });
  console.log(`${cond ? ' ok ' : 'MAL '} ${nombre}${cond ? '' : ' — ' + String(typeof detalle === 'string' ? detalle : JSON.stringify(detalle ?? '')).slice(0, 900)}`);
}

// ---------- las librerías del PDF ----------
function librerias() {
  const probar = (dir) => { try { const rq = createRequire(path.join(dir, 'x.js')); return { PDFLib: rq('pdf-lib'), QRCode: rq('qrcode') }; } catch { return null; } };
  if (process.env.LIBS) { const l = probar(process.env.LIBS); if (l) return l; throw new Error(`LIBS=${process.env.LIBS} no trae pdf-lib y qrcode`); }
  const dir = path.join(os.tmpdir(), 'mxp-facturas-libs');
  let l = probar(dir);
  if (l) return l;
  mkdirSync(dir, { recursive: true });
  if (!existsSync(path.join(dir, 'package.json'))) writeFileSync(path.join(dir, 'package.json'), '{"name":"mxp-facturas-libs","private":true}');
  log(`instalando pdf-lib y qrcode en ${dir} (npm)…`);
  execFileSync('npm', ['install', '--silent', '--no-audit', '--no-fund', 'pdf-lib@1.17.1', 'qrcode@1.5.4'], { cwd: dir, stdio: 'inherit' });
  l = probar(dir);
  if (!l) throw new Error('no pude instalar pdf-lib y qrcode');
  return l;
}

// ---------- la base ----------
const UID = '00000000-0000-4000-a000-000000000001';           // Edgar (el dueño de la semilla del banco)
const CAMPO = '00000000-0000-4000-a000-0000000f1001';          // alguien del equipo (ZZ)
const CORREO_DE = { [UID]: 'zz.edgar@c11-pruebas.invalid', [CAMPO]: 'zz.campo@c11-pruebas.invalid' };
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (sub, aal = 'aal2') => `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub, role: 'authenticated', aal, exp: 4102444800 })}.firma`;
const carga = (tok) => { try { return JSON.parse(Buffer.from(String(tok).split('.')[1], 'base64url').toString()); } catch { return null; } };
function q(sql) {
  return execFileSync('psql', ['-X', '-At', '-F', '|', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-c', sql], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'] }).toString().trim();
}
function pegar(archivo) {
  execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-f', archivo], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'] });
}
function psqlAsync(guion) {
  return new Promise((resolve) => {
    const h = spawn('psql', ['-X', '-q', '-At', '-U', 'editor_sql', '-d', BD, '-f', '-'], { env: PG_ENV });
    let salida = '', error = '';
    h.stdout.on('data', (d) => { salida += d; }); h.stderr.on('data', (d) => { error += d; });
    h.on('close', (codigo) => resolve({ codigo, salida, error }));
    h.stdin.end(guion);
  });
}
const dolar = (s) => { let tag = 'mxp'; while (s.includes(`$${tag}$`)) tag += 'x'; return `$${tag}$${s}$${tag}$`; };
const literal = (v) => v === null || v === undefined ? 'NULL' : typeof v === 'number' || typeof v === 'boolean' ? String(v) : dolar(typeof v === 'string' ? v : JSON.stringify(v));
// una sentencia como quien diga el JWT (authenticated + sus claims), o como el editor (claims vacíos) sin JWT
async function comoQuien(sql, claims) {
  const pre = claims
    ? `select set_config('request.jwt.claims', ${literal(JSON.stringify(claims))}, true) \\gset x_\nset local role authenticated;\n`
    : `select set_config('request.jwt.claims', '', true) as a, set_config('request.jwt.claim.sub', '', true) as b \\gset x_\n`;
  const r = await psqlAsync(`\\set ON_ERROR_STOP 1\n\\set VERBOSITY verbose\nbegin;\n${pre}${sql}\ncommit;\n`);
  if (r.codigo !== 0) {
    const m = r.error.match(/ERROR:\s+([0-9A-Z]{5}):\s+(.*)/);
    const h = r.error.match(/HINT:\s+(.*)/);
    throw Object.assign(new Error(m ? m[2] : r.error.trim().split('\n')[0]), { code: m ? m[1] : 'XX000', hint: h ? h[1] : null });
  }
  return r.salida.trim();
}
const comoEdgar = (sql) => comoQuien(sql, { sub: UID, role: 'authenticated', aal: 'aal2' });
const jsonDe = (t) => { if (!t) return null; try { return JSON.parse(t); } catch { return t; } };

// ---------- la PostgREST, el Storage y el Auth de mentira (SUPABASE_URL) ----------
const objetos = new Map();          // lo que se subió al bucket «facturas»: ruta → bytes
const gw = { rpcFalla: {}, llamadas: [] };
let modStripe = null, modFacturas = null;
const leerCuerpo = (req) => new Promise((ok2) => { const t = []; req.on('data', (d) => t.push(d)); req.on('end', () => ok2(Buffer.concat(t))); });
const JSON_H = { 'Content-Type': 'application/json' };
function errorPostgrest(e) {
  const code = e.code === '42883' ? 'PGRST202' : e.code;
  const estado = code === '42501' ? 403 : code === 'PGRST202' ? 404 : 400;
  return { estado, cuerpo: { code, message: e.message, details: null, hint: e.hint } };
}
async function pasarelaSupabase(req, res) {
  const u = new URL(req.url, `http://127.0.0.1:${P_GW}`);
  const cuerpo = await leerCuerpo(req);
  const tok = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const c = carga(tok);
  const claims = c && tok.endsWith('.firma') ? { sub: c.sub, role: 'authenticated', aal: c.aal } : null;
  const enviar = (estado, o, cab = JSON_H) => { res.writeHead(estado, cab); res.end(Buffer.isBuffer(o) ? o : JSON.stringify(o)); };
  gw.llamadas.push(`${req.method} ${u.pathname}`);
  try {
    if (u.pathname.startsWith('/sitio/')) {
      const f = path.join(R, u.pathname.slice('/sitio/'.length));
      return existsSync(f) ? enviar(200, readFileSync(f), { 'Content-Type': 'image/png' }) : enviar(404, { error: 'no' });
    }
    if (u.pathname === '/auth/v1/user') {
      if (!claims || !CORREO_DE[claims.sub]) return enviar(401, { code: 401, msg: 'invalid JWT' });
      return enviar(200, { id: claims.sub, email: CORREO_DE[claims.sub], aud: 'authenticated' });
    }
    if (u.pathname === '/functions/v1/stripe') {
      const r = await modStripe.atender(new Request(`http://127.0.0.1:${P_GW}/functions/v1/stripe`, { method: req.method, headers: { 'Content-Type': 'application/json', Authorization: req.headers.authorization || '' }, body: cuerpo.toString() }));
      return enviar(r.status, Buffer.from(await r.arrayBuffer()));
    }
    if (!claims) return enviar(401, { code: 'PGRST301', message: 'JWT invalid' });
    if (u.pathname.startsWith('/rest/v1/rpc/')) {
      const fn = u.pathname.slice('/rest/v1/rpc/'.length);
      if (!/^[a-z_0-9]+$/.test(fn)) return enviar(404, { code: 'PGRST202', message: 'no' });
      if (gw.rpcFalla[fn]) { const f = gw.rpcFalla[fn]; delete gw.rpcFalla[fn]; return enviar(400, f); }
      const a = JSON.parse(cuerpo.toString() || '{}');
      try {
        const t = await comoQuien(`select (${fn}(${Object.keys(a).map((k) => `${k} => ${literal(a[k])}`).join(', ')}))::text;`, claims);
        return enviar(200, Buffer.from(t || 'null'));
      } catch (e) { const r = errorPostgrest(e); return enviar(r.estado, r.cuerpo); }
    }
    if (u.pathname === '/rest/v1/perfiles' && req.method === 'GET') {
      const id = (u.searchParams.get('id') || '').replace(/^eq\./, '');
      const t = await comoQuien(`select coalesce(json_agg(t), '[]')::text from (select rol, activo from perfiles where id::text = ${literal(id)}) t;`, claims);
      return enviar(200, Buffer.from(t));
    }
    if (u.pathname === '/rest/v1/correos' && req.method === 'POST') {
      try {
        await comoQuien(`insert into correos (proyecto_id, para, asunto, tipo, resend_id, enviado_por) select proyecto_id, para, asunto, tipo, resend_id, enviado_por from json_populate_record(null::correos, ${literal(cuerpo.toString())});`, claims);
        return enviar(201, Buffer.from(''));
      } catch (e) { const r = errorPostgrest(e); return enviar(r.estado === 400 && /row-level/.test(e.message) ? 403 : r.estado, r.cuerpo); }
    }
    let m;
    if ((m = u.pathname.match(/^\/storage\/v1\/object\/facturas\/(.+)$/)) && req.method === 'POST') {
      const ruta = decodeURIComponent(m[1]);
      try {
        await comoQuien(`insert into storage.objects (bucket_id, name, owner, metadata) values ('facturas', ${literal(ruta)}, auth.uid(), jsonb_build_object('size', ${cuerpo.length}, 'mimetype', ${literal(String(req.headers['content-type'] || ''))}));`, claims);
      } catch (e) {
        if (e.code === '23505') return enviar(409, { statusCode: '409', error: 'Duplicate', message: 'The resource already exists' });
        return enviar(403, { statusCode: '403', error: 'Unauthorized', message: `new row violates row-level security policy (${e.code})` });
      }
      objetos.set(ruta, cuerpo);
      return enviar(200, { Key: `facturas/${ruta}`, Id: `obj-${objetos.size}` });
    }
    if ((m = u.pathname.match(/^\/storage\/v1\/object\/sign\/facturas\/(.+)$/)) && req.method === 'POST') {
      const ruta = decodeURIComponent(m[1]);
      const t = await comoQuien(`select count(*) from storage.objects where bucket_id = 'facturas' and name = ${literal(ruta)};`, claims);
      if (t !== '1') return enviar(400, { statusCode: '404', error: 'not_found', message: 'Object not found' });
      return enviar(200, { signedURL: `/object/sign/facturas/${m[1]}?token=prueba` });
    }
    return enviar(404, { code: 'PGRST205', message: `no conozco ${req.method} ${u.pathname}` });
  } catch (e) {
    return enviar(500, { message: `pasarela: ${e.message}` });
  }
}

// ---------- Stripe: el simulado de p1 con un portero que sabe restringir los métodos ----------
const sim = crearSimulador({ llave: LLAVE, puerto: P_SIM });
const portero = { restringir: [], falla: null };
async function porteroStripe(req, res) {
  const cuerpo = await leerCuerpo(req);
  const u = new URL(req.url, 'http://x');
  const m = u.pathname.match(/^\/v1\/payment_links\/([^/]+)$/);
  if (req.method === 'POST' && m) {
    const p = leerFormulario(cuerpo.toString());
    if (p.payment_method_types !== undefined) {
      const tipos = [].concat(p.payment_method_types);
      portero.restringir.push({ plink: m[1], tipos, idem: req.headers['idempotency-key'] || null, version: req.headers['stripe-version'] || null });
      if (portero.falla) { const f = portero.falla; portero.falla = null; res.writeHead(f.estado, JSON_H); res.end(JSON.stringify(f.cuerpo)); return; }
      const link = sim.estado.links.get(m[1]);
      if (link && req.headers.authorization === `Bearer ${LLAVE}` && tipos.every((t) => ['us_bank_account', 'card'].includes(t))) link.payment_method_types = tipos;
    }
  }
  const r = await fetch(`http://127.0.0.1:${P_SIM}${req.url}`, { method: req.method, headers: { ...Object.fromEntries(Object.entries(req.headers).filter(([k]) => !['host', 'content-length', 'connection'].includes(k))) }, body: req.method === 'GET' ? undefined : cuerpo });
  res.writeHead(r.status, JSON_H); res.end(Buffer.from(await r.arrayBuffer()));
}

// ---------- Resend de mentira ----------
const rs = { correos: [], idem: new Map(), falla: null, n: 0 };
async function resendFalso(req, res) {
  const cuerpo = await leerCuerpo(req);
  const enviar = (e, o) => { res.writeHead(e, JSON_H); res.end(JSON.stringify(o)); };
  if (req.method !== 'POST' || req.url !== '/emails') return enviar(404, { message: 'not found' });
  if (req.headers.authorization !== `Bearer ${RESEND_LLAVE}`) return enviar(401, { statusCode: 401, name: 'validation_error', message: 'API key is invalid' });
  if (rs.falla) { const f = rs.falla; rs.falla = null; return enviar(f.estado, f.cuerpo); }
  const idem = req.headers['idempotency-key'] || null;
  if (idem && rs.idem.has(idem)) return enviar(200, { id: rs.idem.get(idem) });
  const id = `re_sim_${String(++rs.n).padStart(4, '0')}`;
  rs.correos.push({ id, idem, cuerpo: JSON.parse(cuerpo.toString()) });
  if (idem) rs.idem.set(idem, id);
  return enviar(200, { id });
}

// ---------- la función ----------
const ENTORNO = {
  MXP_BANCO_PRUEBAS: '1', SUPABASE_URL: `http://127.0.0.1:${P_GW}`, SUPABASE_ANON_KEY: 'anon-de-prueba',
  STRIPE_SECRET_KEY: LLAVE, STRIPE_WEBHOOK_SECRET: 'whsec_prueba', STRIPE_RUTINA_SECRETO: 'r'.repeat(40), STRIPE_BASE_URL: `http://127.0.0.1:${P_STRIPE}`,
  MXP_DB_URL: `postgres://editor_sql:editor_sql@127.0.0.1:${PGPORT}/${BD}`,
  RESEND_API_KEY: RESEND_LLAVE, RESEND_BASE_URL: `http://127.0.0.1:${P_RESEND}`,
  FACTURAS_REMITENTE: 'ZZ Electric C11 PRUEBA <billing@c11-pruebas.invalid>', FACTURAS_SITIO: `http://127.0.0.1:${P_GW}/sitio/`,
};
let denoUrl = null;
async function llamar(cuerpo, { tok = jwt(UID), deno = false } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (tok) headers.Authorization = `Bearer ${tok}`;
  let r;
  if (deno) r = await fetch(`${denoUrl}/functions/v1/facturas`, { method: 'POST', headers, body: JSON.stringify(cuerpo) });
  else r = await modFacturas.atender(new Request('http://127.0.0.1/functions/v1/facturas', { method: 'POST', headers, body: JSON.stringify(cuerpo) }));
  const texto = await r.text();
  respuestas.push(texto);
  let j = null; try { j = JSON.parse(texto); } catch { /* sin json */ }
  return { estado: r.status, j: j || {} };
}
// la base de la función stripe en este proceso: psql, cada llamada en su transacción, sin claims (como su abrirBase)
const baseStripe = {
  async rpc(fn, args) {
    if (!/^fn_stripe_[a-z_]+$/.test(fn)) throw Object.assign(new Error(`función que no es de p1: ${fn}`), { code: '42501' });
    const t = await comoQuien(`select (${fn}(${Object.keys(args).map((k) => `${k} => ${literal(args[k])}`).join(', ')}))::text;`, null);
    return jsonDe(t);
  },
  async quien(t) {
    const c = carga(t);
    if (!c || !/^[0-9a-f-]{36}$/.test(c.sub ?? '')) return null;
    const r = q(`select rol || '|' || coalesce(activo, true) from perfiles where id = '${c.sub}'`);
    const [rol, activo] = r.split('|');
    return rol ? { id: c.sub, rol, activo: activo === 't' || activo === 'true' } : null;
  },
};

// ---------- utilidades de la escena ----------
const sha = (b) => createHash('sha256').update(b).digest('hex');
const documento = async (id) => jsonDe(await comoEdgar(`select fn_emision_documento(${literal(id)})::text;`));
async function borrador(p) { return jsonDe(await comoEdgar(`select fn_emision_borrador(${literal(p)})::text;`)); }
async function emitir(id, op = {}) {
  const d = await documento(id);
  return jsonDe(await comoEdgar(`select fn_emision_emitir(${literal(id)}, ${literal(d.visto)}, ${literal(op)})::text;`));
}
function textoPdf(bytes, nombre) {
  const f = path.join(FOTOS, `${nombre}.pdf`);
  writeFileSync(f, bytes);
  try { execFileSync('pdftoppm', ['-r', '90', '-png', f, path.join(FOTOS, nombre)], { stdio: 'ignore' }); } catch { /* sin poppler: sin fotos */ }
  try { return execFileSync('pdftotext', ['-layout', f, '-'], { stdio: ['ignore', 'pipe', 'ignore'] }).toString(); } catch { return ''; }
}
const infoPdf = (nombre) => { try { return execFileSync('pdfinfo', [path.join(FOTOS, `${nombre}.pdf`)]).toString(); } catch { return ''; } };
const hijos = [];

// =====================================================================
(async () => {
  // ---- la base ----
  log(`base ${BD} desde ${PLANTILLA}`);
  const crear = () => {
    try { execFileSync('psql', ['-X', '-q', '-U', 'editor_sql', '-d', 'postgres', '-c', `drop database if exists ${BD}`, '-c', `create database ${BD} template ${PLANTILLA} owner editor_sql`], { env: PG_ENV, stdio: 'pipe' }); }
    catch {
      execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', PGPORT, '-c', `drop database if exists ${BD}`, '-c', `create database ${BD} template ${PLANTILLA} owner editor_sql`, '-c', `grant create on database ${BD} to editor_sql`], { stdio: 'pipe' });
    }
  };
  crear();
  pegar(path.join(R, 'docs/conta/c11-emision.sql'));
  pegar(path.join(AQUI, 'correos-replica.sql'));
  q(`insert into auth.users (id, email) values ('${CAMPO}', 'zz.campo@c11-pruebas.invalid') on conflict (id) do nothing`);
  q(`insert into perfiles (id, nombre, rol, activo) values ('${CAMPO}', 'Zzcampo C11 PRUEBA', 'campo', true) on conflict (id) do update set rol = 'campo', activo = true`);
  q(`select fn_mapeo_confirmar('tipo_proyecto', null)`);
  q(`update stripe_config set acepta_prueba = true where id = 1`);
  q(`insert into proyectos (id, tipo, nombre, estado, cliente, direccion, cliente_email) values
       ('u10-prueba-a', 'comercial', 'C11 PRUEBA Oficina Uno', 'ejecucion', 'ZZ Cliente Uno', '1 ZZ Test Rd, Testville, FL 00000', 'zz.uno@c11-pruebas.invalid'),
       ('u10-prueba-b', 'residencial', 'C11 PRUEBA Casa Dos', 'ejecucion', 'ZZ Cliente Dos', '2 ZZ Test Rd, Testville, FL 00000', 'zz.dos@c11-pruebas.invalid')`);
  q(`insert into finanzas_proyecto (proyecto_id, contrato) values ('u10-prueba-a', 18500.55), ('u10-prueba-b', 4000.00)`);
  q(`insert into hitos (id, proyecto_id, titulo, condicion, monto, estado, orden, es_deposito) overriding system value values
       (-1010100001, 'u10-prueba-a', 'C11 PRUEBA Rough-in', 'Due upon passing the rough-in inspection', 1234.57, 'pendiente', 1, false),
       (-1010100002, 'u10-prueba-a', 'C11 PRUEBA Trim-out', null, 17265.98, 'pendiente', 2, false),
       (-1010100003, 'u10-prueba-b', 'C11 PRUEBA Deposit', 'Due at contract signing', 1200.00, 'pendiente', 0, true),
       (-1010100004, 'u10-prueba-b', 'C11 PRUEBA Final', null, 2800.00, 'pendiente', 1, false)`);
  await comoEdgar(`select fn_emision_config(${literal({ corte: HOY, empresa: { nombre: 'ZZ Electric C11 PRUEBA, Inc.', licencia: 'ZZ-0000', direccion: '100 ZZ Test Ave, Testville, FL 00000', telefono: '(000) 000-0000', correo: 'billing@c11-pruebas.invalid', web: 'c11-pruebas.invalid' }, como_pagar: 'Check payable to ZZ Electric C11 PRUEBA, Inc. Please write the invoice number on the check.' })});`);
  await comoEdgar(`select fn_emision_obra('{"proyecto_id":"u10-prueba-a","retencion_pct":10}');`);

  // ---- los servidores y la función ----
  Object.assign(process.env, ENTORNO);
  await sim.escuchar();
  const servir = (fn, p) => new Promise((ok2) => { const s = http.createServer(fn); hijos.push({ kill: () => s.close() }); s.listen(p, '127.0.0.1', ok2); });
  await servir(pasarelaSupabase, P_GW); await servir(porteroStripe, P_STRIPE); await servir(resendFalso, P_RESEND);
  const errorOriginal = console.error; let salidaFn = '';
  console.error = (...a) => { salidaFn += a.map(String).join(' ') + '\n'; };
  modStripe = await import(pathToFileURL(path.join(R, 'supabase/functions/stripe/index.ts')).href);
  modStripe.usarBaseDePruebas(baseStripe);
  modFacturas = await import(pathToFileURL(path.join(R, 'supabase/functions/facturas/index.ts')).href);
  modFacturas.usarLibreriasDePruebas(librerias());

  // ---- quién puede ----
  let r = await llamar({ accion: 'salud' }, { tok: null });
  ok('F01 salud sin sesión: ok, con Resend, la llave de Stripe en modo prueba, el sitio y nada que falte', r.estado === 200 && r.j.ok === true && r.j.resend === true && r.j.stripe === 'prueba' && r.j.banco_de_pruebas === true && Array.isArray(r.j.falta) && r.j.falta.length === 0, r.j);
  r = await llamar({ accion: 'pdf', documento: '00000000-0000-4000-8000-000000000000' }, { tok: null });
  ok('F02 sin sesión → 401 SESION', r.estado === 401 && r.j.codigo === 'SESION', r.j);
  r = await llamar({ accion: 'pdf', documento: '00000000-0000-4000-8000-000000000000' }, { tok: jwt(UID).replace(/firma$/, 'mala') });
  ok('F03 una sesión que Auth no reconoce → 401 SESION', r.estado === 401 && r.j.codigo === 'SESION', r.j);
  r = await llamar({ accion: 'pdf', documento: '00000000-0000-4000-8000-000000000000' }, { tok: jwt(UID, 'aal1') });
  ok('F04 sin el código del teléfono (aal1) → 403 MFA, en llano', r.estado === 403 && r.j.codigo === 'MFA' && /código del teléfono/.test(r.j.error), r.j);
  r = await llamar({ accion: 'pdf', documento: '00000000-0000-4000-8000-000000000000' }, { tok: jwt(CAMPO) });
  ok('F05 alguien del equipo (aal2) → 403 NO_DUENO: «solo Edgar»', r.estado === 403 && r.j.codigo === 'NO_DUENO' && /solo Edgar/.test(r.j.error), r.j);
  r = await llamar({ accion: 'borrar', documento: '00000000-0000-4000-8000-000000000000' });
  ok('F06 una acción que no existe → 400 ACCION con las que hay', r.estado === 400 && r.j.codigo === 'ACCION' && /pdf, enviar, ver y salud/.test(r.j.error), r.j);
  r = await llamar({ accion: 'pdf' });
  ok('F07 sin documento → 400 FORMA', r.estado === 400 && r.j.codigo === 'FORMA', r.j);

  // ---- un borrador no tiene PDF ----
  const bA = await borrador({ forma: 'hito', hito_id: -1010100001 });
  const docA = bA.documento.id;
  r = await llamar({ accion: 'pdf', documento: docA });
  ok('F08 un borrador → 409 MX008 «emítela primero»', r.estado === 409 && r.j.codigo === 'MX008' && /Emítela primero/.test(r.j.error), r.j);

  // ---- el PDF de una factura emitida ----
  const eA = await emitir(docA);
  ok('F09 (escena) emitida la del hito: MXP-AAAA-0001, $1,234.57 con 10 % retenido, a pagar $1,111.11', eA.estado === 'emitida' && /^MXP-\d{4}-0001$/.test(eA.numero) && Number(eA.a_pagar) === 1111.11, eA);
  const plinksAntes = sim.estado.links.size;
  r = await llamar({ accion: 'pdf', documento: docA });
  const pA = r.j.pdf || {};
  const dA = await documento(docA);
  const enlA = q(`select id || '|' || plink || '|' || url || '|' || estado || '|' || monto || '|' || con_retencion from stripe_enlaces where factura_id = ${eA.factura_id} order by creado_el desc limit 1`).split('|');
  ok('F10 pdf: ok, registrado (n 1) con su ruta <año>/<número>/<número>-<sha>.pdf, y una dirección firmada para verlo',
    r.estado === 200 && r.j.ok && r.j.ya_estaba === false && pA.n === 1 && new RegExp(`^${HOY.slice(0, 4)}/${eA.numero}/${eA.numero}-[0-9a-f]{12}\\.pdf$`).test(pA.ruta) && /\/storage\/v1\/object\/sign\/facturas\//.test(r.j.url || ''), r.j);
  ok('F11 el enlace lo armó p1 (stripe_enlaces activo, sin retención, por lo que debe el libro: 1111.11) por la función stripe',
    enlA[3] === 'activo' && enlA[4] === '1111.11' && enlA[5] === 'false' && sim.estado.links.size === plinksAntes + 1 && r.j.enlace && r.j.enlace.enlace_id === enlA[0] && r.j.enlace.url === enlA[2], { enlA, enlace: r.j.enlace });
  const linkA = sim.estado.links.get(enlA[1]);
  ok('F12 en Stripe quedó SOLO por cuenta de banco antes de imprimirlo (POST /v1/payment_links/{plink}, con Idempotency-Key y la versión fija)',
    linkA && JSON.stringify(linkA.payment_method_types) === '["us_bank_account"]' && portero.restringir.length === 1 && portero.restringir[0].plink === enlA[1] && /^mxp-facturas-ach-plink_/.test(portero.restringir[0].idem || '') && portero.restringir[0].version === '2026-09-30.endive' && linkA._monto === 111111,
    { tipos: linkA && linkA.payment_method_types, portero: portero.restringir });
  const objA = objetos.get(pA.ruta);
  ok('F13 el archivo está en el bucket «facturas» (insertado con la RLS del dueño), su sha256 y su tamaño son los registrados',
    objA && sha(objA) === pA.sha256 && objA.length === pA.bytes && q(`select (metadata->>'size')::bigint from storage.objects where bucket_id = 'facturas' and name = '${pA.ruta}'`) === String(pA.bytes), pA);
  ok('F14 la base lo apuntó con el enlace impreso (solo us_bank_account) y la huella del documento',
    dA.pdfs.length === 1 && dA.pdfs[0].pago && JSON.stringify(dA.pdfs[0].pago.metodos) === '["us_bank_account"]' && dA.pdfs[0].pago.url === enlA[2] && q(`select huella = (select huella from emision_documentos where id = '${docA}') from emision_pdfs where id = '${pA.id}'`) === 't', dA.pdfs);
  const tA = textoPdf(objA, 'f-hito');
  const lin = tA.replace(/\s+/g, ' ');
  ok('F15 lo que dice el PDF (en inglés): INVOICE, el número, la fecha, Due on receipt, a quién, la obra, la línea del hito, Subtotal $1,234.57, «Less retainage held (10%) -$123.46», «Amount due $1,111.11», How to pay y el enlace con lo que cobra ($1,111.11)',
    /INVOICE/.test(lin) && lin.includes(`No. ${eA.numero}`) && /Date [A-Z][a-z]{2} \d{1,2}, \d{4}/.test(lin) && /Due on receipt/.test(lin) && /ZZ Cliente Uno/.test(lin) && /C11 PRUEBA Oficina Uno/.test(lin) &&
    /C11 PRUEBA Rough-in/.test(lin) && /Subtotal \$1,234\.57/.test(lin) && /Less retainage held \(10%\) -\$123\.46/.test(lin) && /Amount due \$1,111\.11/.test(lin) && /HOW TO PAY/.test(lin) && lin.includes(enlA[2]) && /Pay \$1,111\.11 online by bank transfer \(ACH\)/.test(lin) && !/balance due today/.test(lin) && /Progress billing #1/.test(lin), lin.slice(0, 1500));
  ok('F16 los metadatos del PDF: el título «Invoice <número>», en inglés, y la huella del contenido en las palabras clave', (() => { const i = infoPdf('f-hito'); return i.includes(`Invoice ${eA.numero}`) && i.includes(`c11:${dA.huella}`); })(), infoPdf('f-hito'));
  r = await llamar({ accion: 'pdf', documento: docA });
  ok('F17 otra vez: el MISMO archivo (ya_estaba), sin otro registro, sin otro objeto y con el mismo enlace (la restricción es idempotente)',
    r.estado === 200 && r.j.ya_estaba === true && r.j.pdf.id === pA.id && (await documento(docA)).pdfs.length === 1 && objetos.size === 1 && sim.estado.links.size === plinksAntes + 1 && r.j.enlace.url === enlA[2], r.j);
  r = await llamar({ accion: 'ver', documento: docA });
  ok('F18 ver: la dirección firmada del último PDF', r.estado === 200 && r.j.pdf.id === pA.id && /token=/.test(r.j.url || ''), r.j);

  // ---- el correo ----
  r = await llamar({ accion: 'enviar', documento: docA, mensaje: 'The rough-in inspection passed today.' });
  const c1 = rs.correos[0] || { cuerpo: {} };
  const adj = (c1.cuerpo.attachments || [])[0] || {};
  ok('F19 enviar: ok, un correo a Resend: de la casa, para el cliente de la obra, copia a Edgar (su sesión), responder-a la empresa, asunto «Invoice … from …»',
    r.estado === 200 && r.j.ok && rs.correos.length === 1 && c1.cuerpo.from === ENTORNO.FACTURAS_REMITENTE && JSON.stringify(c1.cuerpo.to) === '["zz.uno@c11-pruebas.invalid"]' &&
    JSON.stringify(c1.cuerpo.cc) === '["zz.edgar@c11-pruebas.invalid"]' && c1.cuerpo.reply_to === 'billing@c11-pruebas.invalid' && c1.cuerpo.subject === `Invoice ${eA.numero} from ZZ Electric C11 PRUEBA, Inc.`, { r: r.j, correo: { ...c1.cuerpo, html: undefined, text: undefined, attachments: undefined } });
  ok('F20 …con el PDF adjunto («Invoice-<número>.pdf») que es EL REGISTRADO (mismo sha256), y el cuerpo en inglés con el botón de pago y el mensaje de Edgar',
    adj.filename === `Invoice-${eA.numero}.pdf` && sha(Buffer.from(adj.content || '', 'base64')) === pA.sha256 && c1.cuerpo.html.includes(enlA[2]) && /Pay \$1,111\.11 by bank transfer/.test(c1.cuerpo.html) &&
    /The rough-in inspection passed today\./.test(c1.cuerpo.html) && /How to pay/.test(c1.cuerpo.html) && /assets\/membrete-email\.png/.test(c1.cuerpo.html) && /Amount due: \$1,111\.11/.test(c1.cuerpo.text), c1.cuerpo.text);
  const dA2 = await documento(docA);
  ok('F21 el envío quedó en la factura (n 1, correo, para, cc, asunto, el id de Resend, el PDF) y en correos (tipo factura_app)',
    dA2.envios.length === 1 && dA2.envios[0].resend_id === c1.id && dA2.envios[0].pdf_id === pA.id && dA2.envios[0].cc === 'zz.edgar@c11-pruebas.invalid' && r.j.envio.n === 1 && r.j.reenvio === false &&
    q(`select count(*) from correos where resend_id = '${c1.id}' and tipo = 'factura_app' and proyecto_id = 'u10-prueba-a' and enviado_por = '${UID}'`) === '1' && r.j.avisos.length === 0, { envios: dA2.envios, r: r.j });
  r = await llamar({ accion: 'enviar', documento: docA, para: 'zz.otro@c11-pruebas.invalid', cc: 'zz.pm@c11-pruebas.invalid' });
  ok('F22 reenviar (a otro, con otra copia): otro correo (otra llave de idempotencia), n 2, reenvio = true, el mismo PDF',
    r.estado === 200 && rs.correos.length === 2 && rs.correos[1].idem !== rs.correos[0].idem && r.j.envio.n === 2 && r.j.reenvio === true && JSON.stringify(rs.correos[1].cuerpo.cc) === '["zz.edgar@c11-pruebas.invalid","zz.pm@c11-pruebas.invalid"]' && r.j.pdf.id === pA.id, r.j);
  rs.falla = { estado: 500, cuerpo: { statusCode: 500, name: 'application_error', message: 'Resend simulado: caído a propósito' } };
  r = await llamar({ accion: 'enviar', documento: docA });
  ok('F23 Resend caído: 502 RESEND en llano y no se apunta ningún envío', r.estado === 502 && r.j.codigo === 'RESEND' && (await documento(docA)).envios.length === 2, r.j);
  r = await llamar({ accion: 'enviar', documento: docA, para: 'no-es-un-correo' });
  ok('F24 un «para» que no es un correo: 400 FORMA, sin mandar nada', r.estado === 400 && r.j.codigo === 'FORMA' && rs.correos.length === 2, r.j);
  gw.rpcFalla.fn_emision_envio = { code: '55P03', message: 'canceling statement due to lock timeout', details: null, hint: null };
  r = await llamar({ accion: 'enviar', documento: docA });
  const id3 = r.j.datos && r.j.datos.resend_id;
  ok('F25 el correo sale y no se apunta: 500 SIN_APUNTAR con el id de Resend en datos (para apuntarlo sin volver a mandarlo)', r.estado === 500 && r.j.codigo === 'SIN_APUNTAR' && id3 === rs.correos[2].id && /no se vuelve a mandar/.test(r.j.error), r.j);
  const ap = jsonDe(await comoEdgar(`select fn_emision_envio(${literal(docA)}, ${literal({ medio: 'correo', para: r.j.datos.para, cc: r.j.datos.cc, asunto: r.j.datos.asunto, resend_id: id3, pdf_id: r.j.datos.pdf_id })})::text;`));
  ok('F26 …y apuntarlo con ese id (lo que hace «Apuntar el envío» de la pantalla): n 3, sin otro correo', ap.envio.n === 3 && rs.correos.length === 3, ap);
  q(`drop policy "correos: el dueno" on correos`);
  r = await llamar({ accion: 'enviar', documento: docA });
  ok('F27 la tabla correos no deja (sin policy): se manda y se apunta en la factura igual, con un aviso en llano', r.estado === 200 && r.j.envio.n === 4 && r.j.avisos.some((a) => /no en el registro de correos/.test(a)), r.j);
  q(`create policy "correos: el dueno" on correos for all to authenticated using (public.es_dueno()) with check (public.es_dueno())`);

  // ---- Stripe no deja restringir el enlace; la llave sin permiso ----
  const bB = await borrador({ forma: 'hito', hito_id: -1010100003 });
  const eB = await emitir(bB.documento.id);
  portero.falla = { estado: 400, cuerpo: { error: { type: 'invalid_request_error', message: 'Received unknown parameter: payment_method_types', param: 'payment_method_types' } } };
  r = await llamar({ accion: 'pdf', documento: bB.documento.id });
  ok('F28 Stripe no deja restringir el enlace a cuenta de banco: 502 STRIPE_ACH, en llano, y NO se registra ningún PDF', r.estado === 502 && r.j.codigo === 'STRIPE_ACH' && /solo por cuenta de banco/.test(r.j.error) && (await documento(bB.documento.id)).pdfs.length === 0, r.j);
  r = await llamar({ accion: 'pdf', documento: bB.documento.id, sin_enlace: true });
  const tB = textoPdf(objetos.get(r.j.pdf && r.j.pdf.ruta) || Buffer.alloc(0), 'f-deposito-sin-enlace');
  ok('F29 …el PDF sin enlace (sin_enlace): registrado sin pago en línea, dice «Deposit» y How to pay, ningún buy.stripe ni enlace del simulado, con su aviso',
    r.estado === 200 && r.j.enlace === null && JSON.stringify((await documento(bB.documento.id)).pdfs[0].pago) === '{}' && /Deposit/.test(tB) && /HOW TO PAY/.test(tB) && !/pagar\/plink_/.test(tB) && r.j.avisos.some((a) => /lo pediste así/.test(a)), r.j);
  sim.estado.sinPermiso.push({ ruta: '/v1/payment_links/', metodo: 'POST', rak: 'rak_payment_link_write' });
  r = await llamar({ accion: 'pdf', documento: bB.documento.id });
  ok('F30 la llave sin permiso de escribir Payment Links: 502 STRIPE_PERMISO en llano', r.estado === 502 && r.j.codigo === 'STRIPE_PERMISO' && /Payment Links: Write/.test(r.j.error), r.j);
  sim.estado.sinPermiso.length = 0;
  r = await llamar({ accion: 'pdf', documento: bB.documento.id });
  ok('F31 con permiso otra vez: PDF nuevo (n 2, otro nombre) con el enlace, solo por cuenta de banco', r.estado === 200 && r.j.pdf.n === 2 && r.j.enlace && JSON.stringify(sim.estado.links.get(q(`select plink from stripe_enlaces where factura_id = ${eB.factura_id} and estado = 'activo'`)).payment_method_types) === '["us_bank_account"]', r.j);

  // ---- el enlace desfasado: un cobro parcial cambia lo que el libro debe ----
  await comoEdgar(`select fn_cobro_registrar(${literal({ fecha: HOY, monto: '100.00', medio: 'cheque', referencia: 'ZZ-U10', aplicaciones: [{ factura_id: eA.factura_id, monto: '100.00' }] })});`);
  r = await llamar({ accion: 'pdf', documento: docA });
  const enlA2 = q(`select plink || '|' || url || '|' || monto from stripe_enlaces where factura_id = ${eA.factura_id} and estado = 'activo'`).split('|');
  ok('F32 tras un cobro de $100.00 el enlace vivo cobraba de más: p1 lo reemplaza (el viejo, inactivo en Stripe), el nuevo cobra 1011.11, solo ACH, y el PDF es otra versión con la nueva dirección',
    r.estado === 200 && r.j.pdf.n === 2 && enlA2[2] === '1011.11' && enlA2[0] !== enlA[1] && sim.estado.links.get(enlA[1]).active === false && JSON.stringify(sim.estado.links.get(enlA2[0]).payment_method_types) === '["us_bank_account"]' &&
    (() => { const t = textoPdf(objetos.get(r.j.pdf.ruta), 'f-hito-v2').replace(/\s+/g, ' '); return t.includes(enlA2[1]) && /Pay \$1,011\.11 online by bank transfer \(ACH\)/.test(t) && /balance due today/.test(t) &&
      /Invoice amount due \$1,111\.11/.test(t) && /Balance due today \$1,011\.11/.test(t) && !/Amount due \$1,111\.11/.test(t); })(), { r: r.j, enlA2 });
  r = await llamar({ accion: 'enviar', documento: docA });
  const cV = rs.correos[rs.correos.length - 1].cuerpo;
  ok('F32b …y el correo: el botón dice lo que cobra el enlace ($1,011.11), que es el saldo de hoy, y la fila grande es «Balance due today» (la factura, «Invoice amount due»)', r.estado === 200 && /Pay \$1,011\.11 by bank transfer/.test(cV.html) && /balance due today/.test(cV.html) && cV.html.includes(enlA2[1]) &&
    /Invoice amount due: \$1,111\.11/.test(cV.text) && /Balance due today: \$1,011\.11/.test(cV.text) && !/^Amount due:/m.test(cV.text), cV.text);

  // ---- la de la retención: sin enlace propio ----
  const bR = await borrador({ forma: 'retencion', proyecto_id: 'u10-prueba-a' });
  const eR = await emitir(bR.documento.id);
  const n0 = portero.restringir.length;
  r = await llamar({ accion: 'pdf', documento: bR.documento.id });
  const tR = textoPdf(objetos.get(r.j.pdf && r.j.pdf.ruta) || Buffer.alloc(0), 'f-retencion');
  ok('F33 la factura de la retención: PDF sin enlace (ni se pide a p1), «Retainage release», «Retainage released $123.46» y el total', r.estado === 200 && r.j.enlace === null && portero.restringir.length === n0 &&
    /Retainage release/.test(tR) && /Retainage released\s+\$123\.46/.test(tR) && /Amount due\s+\$123\.46/.test(tR) && eR.estado === 'emitida', r.j);
  ok('F33b …su «How to pay» (el de la casa, sin hablar de enlaces) sale igual y sin aviso; uno que hablara de «the secure link» avisaría en un PDF sin enlace',
    /Check payable to ZZ Electric C11 PRUEBA, Inc\./.test(tR) && !(r.j.avisos || []).length && modFacturas._probar.hablaDeEnlace('Bank transfer (ACH): use the secure link in the email.') === true &&
    modFacturas._probar.hablaDeEnlace('Pay online with the button') === true && modFacturas._probar.hablaDeEnlace('Check payable to ZZ Electric C11 PRUEBA, Inc. Please write the invoice number on the check.') === false, r.j);

  // ---- anulada: ni PDF ni correo ----
  const bT = await borrador({ forma: 'tm', proyecto_id: 'u10-prueba-b', lineas: [{ descripcion: 'Electrician labor', tipo: 'horas', cantidad: '8', unidad: 'hr', precio: '85.00' }, { descripcion: 'Wire, boxes and connectors', tipo: 'material', cantidad: '1', precio: '412.37', detalle: 'Per supplier receipt' }] });
  const eT = await emitir(bT.documento.id);
  r = await llamar({ accion: 'pdf', documento: bT.documento.id });
  const tT = textoPdf(objetos.get(r.j.pdf.ruta), 'f-tm');
  ok('F34 una T&M: QTY/RATE/AMOUNT con «8 hr» a $85.00 = $680.00, el material y «Time & materials»', r.estado === 200 && /Time & materials/.test(tT) && /8 hr\s+\$85\.00\s+\$680\.00/.test(tT) && /\$412\.37/.test(tT) && /Amount due\s+\$1,092\.37/.test(tT), tT.slice(0, 1200));
  await comoEdgar(`select fn_emision_anular(${literal(bT.documento.id)}, 'ZZ prueba: se facturó a la obra equivocada', null);`);
  r = await llamar({ accion: 'pdf', documento: bT.documento.id });
  const r2 = await llamar({ accion: 'enviar', documento: bT.documento.id });
  ok('F35 una anulada: ni PDF ni correo (409 MX008 con su nota de crédito)', r.estado === 409 && r.j.codigo === 'MX008' && /anulada \(nota de crédito NC-/.test(r.j.error) && r2.estado === 409 && rs.correos.length === 5 && eT.estado === 'emitida', { r: r.j, r2: r2.j });

  // ---- Deno: la misma función, el mismo archivo ----
  const deno = [DENO, path.join(os.tmpdir(), 'deno')].find((x) => x && existsSync(x));
  if (deno) {
    const bD = await borrador({ forma: 'hito', hito_id: -1010100004 });
    await emitir(bD.documento.id);
    let salida = '';
    const h = spawn(deno, ['run', '--quiet', '-A', path.join(R, 'supabase/functions/facturas/index.ts')], { stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...ENTORNO, MXP_PUERTO: String(P_DENO) } });
    hijos.push(h); h.stdout.on('data', (d) => { salida += d; }); h.stderr.on('data', (d) => { salida += d; });
    denoUrl = `http://127.0.0.1:${P_DENO}`;
    let vivo = false;
    for (let i = 0; i < 240 && !vivo; i++) { try { const s = await fetch(`${denoUrl}/`, { method: 'POST', body: '{"accion":"salud"}' }); vivo = s.ok; } catch { await new Promise((x) => setTimeout(x, 500)); } }
    if (!vivo) ok('F36 en Deno: la función arranca', false, salida.slice(-1500));
    else {
      const rd = await llamar({ accion: 'pdf', documento: bD.documento.id }, { deno: true });
      const rn = await llamar({ accion: 'pdf', documento: bD.documento.id });
      ok('F36 en Deno (npm:pdf-lib y npm:qrcode): el PDF sale y se registra; en Node, el MISMO archivo byte a byte (ya_estaba, mismo sha256)',
        rd.estado === 200 && rd.j.pdf && rd.j.pdf.n === 1 && rn.estado === 200 && rn.j.ya_estaba === true && rn.j.pdf.sha256 === rd.j.pdf.sha256, { deno: rd.j, node: rn.j, salida: salida.slice(-800) });
      const rs2 = await llamar({ accion: 'enviar', documento: bD.documento.id }, { deno: true });
      ok('F37 en Deno: enviar (el correo con su adjunto y el envío apuntado)', rs2.estado === 200 && rs2.j.envio && rs2.j.envio.n === 1, rs2.j);
    }
  } else ok('F36 en Deno: omitida (no hay Deno en esta máquina: DENO=<ruta>)', true);

  // ---- ninguna llave ----
  const todo = respuestas.join('\n') + JSON.stringify(rs.correos.map((c) => ({ ...c.cuerpo, attachments: undefined })));
  ok('F38 ninguna llave (Stripe ni Resend) en ninguna respuesta ni en ningún correo', !todo.includes(LLAVE) && !todo.includes(RESEND_LLAVE) && !todo.includes('whsec_prueba'));
  ok('F39 la función no escribió nada raro en la consola', !/facturas:/.test(salidaFn), salidaFn.slice(-600));
  console.error = errorOriginal;

  const mal = resultados.filter((x) => !x.ok).length;
  console.log(`\nfacturas-e2e: ${resultados.length - mal}/${resultados.length} ok · fotos en ${FOTOS}`);
  await fin(mal ? 1 : 0);
})().catch(async (e) => { console.error('El arnés se cayó:', e); await fin(2); });

async function fin(codigo) {
  for (const h of hijos) { try { h.kill(); } catch { /* nada */ } }
  try { sim.servidor.close(); } catch { /* nada */ }
  if (!process.env.CONSERVAR) {
    try { execFileSync('psql', ['-X', '-q', '-U', 'editor_sql', '-d', 'postgres', '-c', `drop database if exists ${BD}`], { env: PG_ENV, stdio: 'pipe' }); }
    catch { try { execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', PGPORT, '-c', `drop database if exists ${BD}`], { stdio: 'pipe' }); } catch { /* nada */ } }
  }
  process.exit(codigo);
}
