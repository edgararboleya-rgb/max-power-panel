/* f15-capturar.js — LA BASE SIMULADA de la página «Nómina» (c15, la Fase 11)
   de pruebas/conta/pantalla.js, SACADA DEL BANCO (la forma de f12-capturar.js).

   No hay una mentira escrita a mano para esta capa: cada respuesta que la
   pantalla recibe en pantalla.js es la que dio el banco (Postgres 17 en
   127.0.0.1:5433) a la misma llamada, como el dueño (authenticated, aal2).
   Este script:
     1. arma <bd> (BORRA la que haya con ese nombre): un clon de la plantilla
        (de fábrica g12a: la cadena entera pegada como en producción, sin
        nómina) con c15-nomina.sql y f15-semilla.sql (tres personas, dos
        obras, sus horas de un período de octubre y los cargos de Gusto en el
        banco, todo inventado);
     2. lee todo lo que la pantalla lee (la ESCENA 0), y después hace, EN EL
        ORDEN DE LA PRUEBA, cada cosa que la pantalla escribe (un PASO: subir
        el journal, decir qué es una columna, enlazar a la gente, postear,
        casar los cargos, el bono, la otra nómina del mismo día, el lote de
        horas, el amarre…), y tras cada paso lo vuelve a leer todo (la escena
        siguiente). Un paso «externo» es algo que no hace la pantalla (una hora
        que se aprueba en la app después del lote);
     3. prueba, sin dejar nada, los errores que la pantalla enseña (sin el
        código del teléfono, el equipo, lo visto que ya cambió, un cargo ya
        casado, un monto mal escrito…);
     4. escribe pruebas/conta/pantalla-f15.json: cada fila una vez (por su
        huella), de cada escena solo lo que cambió respecto de la anterior, y
        los TRES ARCHIVOS que sube la prueba (los CSV sintéticos, con sus
        columnas delicadas DE MENTIRA: «SSN» 000-00-000N, que no existe, y
        «Home address» en una calle falsa). Lo que la pantalla manda de ellos
        es lo que este script manda: las celdas como texto, SIN las columnas
        delicadas (las de clase «delicado» del mapeo y la que trae algo con
        forma de Seguro Social), con la misma regla que js/conta.js
        (nominaLimpiar); pantalla.js compara las dos, celda por celda.
   pantalla.js lo carga: una lectura sale de la escena en que va la cadena;
   una escritura que coincide con el paso siguiente (por su función y sus
   llaves) pasa a la escena de ese paso y contesta lo que contestó el banco;
   los errores los elige la mentira con la misma regla que la base y contesta
   el del banco.

   Uso (solo el banco; nada de red):
     node pruebas/conta/f15-capturar.js <bd> [plantilla=g12a]
   Tarda un minuto. La base queda (con lo que escribieron los pasos); se borra
   a mano: runuser -u postgres -- psql -X -h /var/run/postgresql -p 5433 -c "drop database <bd>". */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { execFileSync } = require('child_process');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--'));
const BD = ARGS[0], PLANTILLA = ARGS[1] || 'g12a';
const PLANTILLAS = ['g12a', 'g10a', 'g9a', 'g8a', 'f9fix', 'p1fab', 'c9perf'];
if (!BD || !/^[a-z][a-z0-9_]*$/.test(BD) || PLANTILLAS.includes(BD) || BD === PLANTILLA) {
  console.error('uso: node pruebas/conta/f15-capturar.js <bd nueva> [plantilla=g12a]   (nunca una plantilla)'); process.exit(2);
}
const ROOT = path.resolve(__dirname, '..', '..');
const SALIDA = path.join(__dirname, 'pantalla-f15.json');
const ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT: '5433', PGPASSWORD: 'editor_sql' };
const DUENO = '00000000-0000-4000-a000-000000000001', EQUIPO = '00000000-0000-4000-a000-000000000002';
const P_UNO = '00000000-0000-4000-a000-0000000015a1', P_DOS = '00000000-0000-4000-a000-0000000015a2', P_TRES = '00000000-0000-4000-a000-0000000015a3';

// ---------- el banco ----------
const su = sql => execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', '5433', '-v', 'ON_ERROR_STOP=1', '-c', sql], { stdio: ['ignore', 'pipe', 'pipe'] });
function pegar(archivo) {
  // como el SQL Editor: editor_sql, una transacción, para al primer error
  execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-f', archivo], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
}
function psql(sql) {
  return execFileSync('psql', ['-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-f', '-'], { env: ENV, input: sql, stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 1 << 28 }).toString();
}
const dolar = s => { let t = 'q'; while (s.includes(`$${t}$`)) t += 'x'; return `$${t}$${s}$${t}$`; };
// Una orden como la pantalla por PostgREST: quien (dueno | equipo), su nivel (aal2 | aal1) y la consulta, que devuelve un jsonb.
// Un error vuelve como {ERROR, message, detail, hint} y lo que hizo esa orden se deshace (el bloque con excepción).
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
function pedir(ordenes, fin = 'commit') {
  const sql = ['begin;', AYUDA, ...ordenes.map(o => `select coalesce(pg_temp.pedir(${dolar(o.sql)}, '${o.quien || 'dueno'}', '${o.aal || 'aal2'}')::text, 'null');`), fin + ';'].join('\n');
  const out = psql(sql).split('\n').filter(l => l.length);
  if (out.length !== ordenes.length) throw new Error(`pedí ${ordenes.length} y contestó ${out.length}`);
  return out.map(l => JSON.parse(l));
}
// lo que PostgREST contesta a un error: el código, el mensaje y su estado HTTP (PGRST: el que dice su detalle; 42501: 403)
function comoPostgrest(e) {
  if (e.ERROR === 'PGRST') {
    let cuerpo = {}, det = {};
    try { cuerpo = JSON.parse(e.message); } catch { cuerpo = { code: 'PGRST', message: e.message }; }
    try { det = JSON.parse(e.detail || '{}'); } catch { det = {}; }
    return { status: Number(det.status) || 400, error: { code: cuerpo.code || null, message: cuerpo.message || null, details: cuerpo.details || null, hint: cuerpo.hint || null } };
  }
  return { status: e.ERROR === '42501' ? 403 : 400, error: { code: e.ERROR, message: e.message, details: e.detail || null, hint: e.hint || null } };
}
const filasDe = consulta => `coalesce((select jsonb_agg(to_jsonb(x)) from (${consulta}) x), '[]'::jsonb)`;
const q = v => v == null ? 'null' : `'${String(v).replace(/'/g, "''")}'`;
const jb = o => `${q(JSON.stringify(o))}::jsonb`;
const uno = sql => JSON.parse(psql(`select coalesce(to_jsonb((${sql})), 'null')::text;`).trim());
const lista = sql => JSON.parse(psql(`select coalesce(jsonb_agg(x), '[]')::text from (${sql}) t(x);`).trim());

// ---------- 1. armar la base ----------
console.log(`armando ${BD} desde ${PLANTILLA}…`);
su(`drop database if exists ${BD}`);
su(`create database ${BD} template ${PLANTILLA} owner editor_sql`);
su(`grant create on database ${BD} to editor_sql`);
pegar(path.join(ROOT, 'docs/conta/c15-nomina.sql')); console.log('  pegado docs/conta/c15-nomina.sql');
execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-f', path.join(__dirname, 'f15-semilla.sql')], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
console.log('  semilla puesta');

// ---------- 2. los archivos que sube la prueba (CSV sintéticos; las columnas delicadas son DE MENTIRA) ----------
const CAB = ['Employee first name', 'Employee last name', 'Pay period start', 'Pay period end', 'Check date', 'Payroll type', 'Payment method', 'Regular hours',
  'Regular earnings', 'Overtime hours', 'Overtime earnings', 'Gross earnings', 'Employee federal income tax', 'Employee social security tax', 'Employee medicare tax',
  'Employee medicare additional tax', 'Employee taxes', 'Employee deductions', 'Net pay', 'Reimbursements', 'Check amount', 'Employer social security tax',
  'Employer medicare tax', 'Employer FUTA tax', 'Employer SUTA tax', 'Employer taxes', 'Employer cost'];
const PER = '10/05/2026,10/18/2026,10/23/2026';
const FILAS_J = [
  `ZZ Ayudante,Uno,${PER},Regular,Direct Deposit,80.00,1760.00,6.00,198.00,1958.00,142.00,121.40,28.39,0.00,291.79,0.00,1666.21,0.00,1666.21,121.40,28.39,11.75,52.87,214.41,2172.41`,
  `ZZ Ayudante,Dos,${PER},Regular,Direct Deposit,72.50,1450.00,0.00,0.00,1450.00,96.00,89.90,21.03,0.00,206.93,50.00,1193.07,0.00,1193.07,89.90,21.03,8.70,39.15,158.78,1608.78`,
  `ZZ Oficial,Tres,${PER},Regular,Direct Deposit,80.00,2400.00,0.00,0.00,2400.00,265.00,148.80,34.80,0.00,448.60,0.00,1951.40,64.25,2015.65,148.80,34.80,14.40,64.80,262.80,2662.80`
];
const TOT_J = 'Totals,,,,,,,232.50,5610.00,6.00,198.00,5808.00,503.00,360.10,84.22,0.00,947.32,50.00,4810.68,64.25,4874.93,360.10,84.22,34.85,156.82,635.99,6443.99';
// el journal de la nómina del 23-oct, con su preámbulo, dos columnas delicadas (después del apellido), una que el mapeo no conoce
// («ZZ Dato raro», con cifras) y otra («ZZ Nota») con algo con forma de Seguro Social en una celda
const DELI = [['000-00-0001', '1 ZZ Calle Falsa'], ['000-00-0002', '2 ZZ Calle Falsa'], ['000-00-0003', '"3 ZZ Calle Falsa, Apt 1"']];
const conDelicado = (l, i) => { const c = l.split(','); return [c[0], c[1], ...DELI[i], ...c.slice(2)].join(','); };
const JOURNAL = ['C15 PRUEBA ZZ Electric Inc', 'Payroll journal', 'Check date: 10/23/2026 - 10/23/2026', '',
  ['Employee first name', 'Employee last name', 'SSN', 'Home address', ...CAB.slice(2), 'ZZ Dato raro', 'ZZ Nota'].join(','),
  ...FILAS_J.map((l, i) => `${conDelicado(l, i)},${7 + i},${i === 1 ? 'ZZ ver 000-00-0009' : ''}`),
  `${TOT_J.split(',').slice(0, 2).join(',')},,,${TOT_J.split(',').slice(2).join(',')},,`].join('\r\n') + '\r\n';
// el bono fuera de ciclo del mismo día de pago (una persona)
const BONO = ['Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Bonus,Gross earnings,Employee federal income tax,' +
  'Employee social security tax,Employee medicare tax,Employee taxes,Net pay,Check amount,Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes',
  `ZZ Ayudante,Uno,${PER},Bonus,Direct Deposit,500.00,500.00,50.00,31.00,7.25,88.25,411.75,411.75,31.00,7.25,3.00,13.50,54.75`].join('\n') + '\n';
// la misma nómina bajada otra vez de Gusto con OTRAS cifras (a ZZ Ayudante Uno, 10.00 de deducción): sin las columnas de más
const OTRA = [CAB.join(','),
  FILAS_J[0].replace(',0.00,1666.21,0.00,1666.21,', ',10.00,1656.21,0.00,1656.21,'), FILAS_J[1], FILAS_J[2],
  TOT_J.replace(',50.00,4810.68,64.25,4874.93,', ',60.00,4800.68,64.25,4864.93,')].join('\n') + '\n';
const ARCHIVOS = { journal: { nombre: 'zz-c15-journal-23oct.csv', texto: JOURNAL }, bono: { nombre: 'zz-c15-bono-23oct.csv', texto: BONO },
  otra: { nombre: 'zz-c15-journal-23oct-v2.csv', texto: OTRA } };

// LAS CELDAS, como las lee la pantalla (comillas, comas dentro, BOM, CRLF) y LO QUE NO SALE DEL TELÉFONO, con la regla de js/conta.js
// (nominaLimpiar): una fila con dos o más nombres del mapeo es una cabecera (abre una sección); en cada sección se quitan las
// columnas de clase «delicado» y las de clase desconocida o «ignorar» que traigan algo con forma de Seguro Social (###-##-####);
// lo de antes de la primera cabecera (el preámbulo) se queda, sin esas celdas. Si una columna que SÍ se guarda trae esa forma,
// el archivo no se manda.
function celdas(t) {
  const filas = []; let f = [], c = '', dentro = false;
  t = t.replace(/^﻿/, '').replace(/\r\n?/g, '\n');
  for (let i = 0; i < t.length; i++) {
    const ch = t[i];
    if (dentro) { if (ch === '"') { if (t[i + 1] === '"') { c += '"'; i++; } else dentro = false; } else c += ch; }
    else if (ch === '"') dentro = true;
    else if (ch === ',') { f.push(c); c = ''; }
    else if (ch === '\n') { f.push(c); filas.push(f); f = []; c = ''; }
    else c += ch;
  }
  if (c !== '' || f.length) { f.push(c); filas.push(f); }
  return filas;
}
const norm = s => String(s == null ? '' : s).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
const FORMA_SSN = /(^|[^0-9])[0-9]{3}-[0-9]{2}-[0-9]{4}([^0-9]|$)/;
function limpiar(filas, mapa) {
  const cab = filas.map(f => f.filter(x => mapa.has(norm(x))).length >= 2);
  const quitar = new Array(filas.length).fill(null).map(() => new Set());
  let ini = -1;
  const cerrar = (a, b) => {
    if (a < 0) return;
    const fuera = new Set();
    filas[a].forEach((x, j) => { if (mapa.get(norm(x)) === 'delicado') fuera.add(j); });
    for (let i = a + 1; i < b; i++) filas[i].forEach((x, j) => {
      if (!FORMA_SSN.test(x) || fuera.has(j)) return;
      const k = mapa.get(norm(filas[a][j]));
      if (k && k !== 'ignorar') throw new Error(`la columna «${filas[a][j]}» trae algo con forma de Seguro Social`);
      fuera.add(j);
    });
    for (let i = a; i < b; i++) quitar[i] = fuera;
  };
  filas.forEach((f, i) => { if (cab[i]) { cerrar(ini, i); ini = i; } });
  cerrar(ini, filas.length);
  return filas.map((f, i) => f.filter((x, j) => !quitar[i].has(j)).map(x => (FORMA_SSN.test(x) ? '' : x)));
}
const MAPA = new Map(lista(`select jsonb_build_array(alias, clase) from nomina_columnas`).map(([a, k]) => [a, k]));
const sha = t => crypto.createHash('sha256').update(Buffer.from(t, 'utf8')).digest('hex');
const enviar = k => { const a = ARCHIVOS[k]; return { nombre: a.nombre, sha256: sha(a.texto), bytes: Buffer.byteLength(a.texto, 'utf8'), filas: limpiar(celdas(a.texto), MAPA) }; };
for (const k of Object.keys(ARCHIVOS)) {
  const s = JSON.stringify(enviar(k));
  if (/000-00-000|Calle Falsa|"SSN"|Home address|ZZ Nota/.test(s)) throw new Error(`lo que se manda de «${k}» lleva algo delicado`);
}

// ---------- los ids que la prueba necesita ----------
const MOV = Object.fromEntries(['fee', 'net', 'tax', 'csd'].map(k => [k, uno(`select id from movimientos_banco where id_externo = 'c15-pantalla-${k}'`)]));
for (const [k, v] of Object.entries(MOV)) if (!v) throw new Error('falta el movimiento ' + k);
const persona = nombre => uno(`select id from nomina_personas where nombre = ${q(nombre)}`);

// ---------- 3. lo que la pantalla lee (las claves dependen de lo que haya: corridas, cargos, lotes) ----------
const RANGOS = [['2026-10-05', '2026-10-18'], ['2026-10-19', '2026-11-01']];
function lecturas() {
  const corridas = lista(`select id from nomina_corridas order by importada_el`);
  const lotes = lista(`select id from nomina_lotes order by creado_el`);
  const movs = Object.values(MOV);
  const o = [];
  o.push({ k: 'v_nomina_control', sql: 'select ' + filasDe(`select * from v_nomina_control order by orden`) });
  o.push({ k: 'v_nomina_corridas', sql: 'select ' + filasDe(`select * from v_nomina_corridas order by dia_pago desc, importada_el desc`) });
  o.push({ k: 'v_nomina_personas', sql: 'select ' + filasDe(`select * from v_nomina_personas order by nombre`) });
  o.push({ k: 'v_nomina_cargos', sql: 'select ' + filasDe(`select * from v_nomina_cargos order by fecha desc, monto desc`) });
  o.push({ k: 'v_nomina_lotes', sql: 'select ' + filasDe(`select * from v_nomina_lotes order by creado_el desc`) });
  o.push({ k: 'nomina_columnas', sql: 'select ' + filasDe(`select * from nomina_columnas order by alias`) });
  o.push({ k: 'perfiles', sql: 'select ' + filasDe(`select id, nombre, rol, activo from perfiles order by nombre`) });
  o.push({ k: 'fn_nomina_config|', sql: `select fn_nomina_config(null)` });
  o.push({ k: 'fn_nomina_amarre|2026', sql: 'select ' + filasDe(`select * from fn_nomina_amarre(2026)`) });
  for (const c of corridas) {
    o.push({ k: `fn_nomina_propuesta|${c}`, sql: `select fn_nomina_propuesta(${q(c)}::uuid)` });
    o.push({ k: `fn_nomina_pendiente|${c}`, sql: 'select ' + filasDe(`select * from fn_nomina_pendiente(${q(c)}::uuid) order by cuenta`) });
  }
  for (const m of movs) o.push({ k: `fn_nomina_cargo_propuesta|${m}`, sql: `select fn_nomina_cargo_propuesta(${q(m)}::uuid)` });
  for (const [d, h] of RANGOS) o.push({ k: `fn_nomina_horas_gusto|${d}|${h}`, sql: 'select ' + filasDe(`select * from fn_nomina_horas_gusto('${d}', '${h}')`) });
  for (const l of lotes) o.push({ k: `fn_nomina_lote_csv|${l}`, sql: `select to_jsonb(fn_nomina_lote_csv(${q(l)}::uuid))` });
  // (las cuatro filas que la nómina le da al cierre del mes: c9 las pide con su bloque; la pantalla del cierre las lleva a «Nómina»)
  for (const p of ['2026-10', '2026-11']) o.push({ k: `fn_nomina_cierre|${p}`, sql: 'select ' + filasDe(`select * from fn_nomina_cierre('${p}') order by orden`) });
  // (la Bandeja del banco: las filas de los cargos de Gusto, como las da c6, para la tarjeta con «Casar con la nómina»)
  o.push({ k: 'v_banco_bandeja', sql: 'select ' + filasDe(`select * from v_banco_bandeja where movimiento_id in (${movs.map(m => q(m) + '::uuid').join(', ')}) order by fecha, movimiento_id`) });
  return o;
}

// ---------- 4. el almacén: cada fila una vez, por su huella ----------
const FILAS = {};
const huella = v => crypto.createHash('sha1').update(JSON.stringify(v)).digest('hex').slice(0, 12);
function guardar(v) {
  if (!Array.isArray(v)) return { valor: v };
  return { filas: v.map(f => { const h = huella(f); FILAS[h] = f; return h; }) };
}
function escena(acumulado, paso) {
  const lect = lecturas(), r = pedir(lect.map(x => ({ sql: x.sql })));
  const cambia = {};
  lect.forEach((x, i) => {
    if (r[i] && r[i].ERROR) throw new Error(`la lectura ${x.k} dio ${r[i].ERROR}: ${r[i].message}`);
    const g = guardar(r[i]), s = JSON.stringify(g);
    if (acumulado[x.k] !== s) { cambia[x.k] = g; acumulado[x.k] = s; }
  });
  return { paso: paso || null, lecturas: cambia };
}

// ---------- 5. los pasos (lo que la pantalla escribe, en el orden de la prueba) ----------
const ID = { mov: MOV, perfil: { uno: P_UNO, dos: P_DOS, tres: P_TRES } };
const T = {
  raro: 'ZZ: el número de la tarjeta de fichar; no es dinero',
  dos: 'ZZ: sus horas de la semana se aprueban tarde; su sueldo va sin obra esta vez',
  deshacer: 'ZZ: lo casé con la nómina equivocada',
  anular: 'ZZ: el bono se pagó dos veces en Gusto y se revirtió',
  descartar: 'ZZ: era la misma nómina bajada otra vez, con una corrección de Gusto que no vale',
  lote: 'ZZ: las horas de la quincena para Gusto'
};
const llama = (fn, args) => ({ sql: `${fn}(${args.map(a => a.sql).join(', ')})`, json: Object.fromEntries(args.map(a => [a.k, a.v])) });
const A = (k, v, tipo) => ({ k, v, sql: v == null ? 'null' : tipo === 'jsonb' ? jb(v) : tipo === 'uuid' ? `${q(v)}::uuid` : tipo === 'date' ? `${q(v)}::date` : tipo === 'int' ? String(v) : q(v) });
const ensayo = (k, op = {}) => () => llama('fn_nomina_ensayo', [A('p_archivo', enviar(k), 'jsonb'), A('p_opciones', op, 'jsonb')]);
const importar = (k, op = {}) => () => llama('fn_nomina_importar', [A('p_archivo', enviar(k), 'jsonb'), A('p_opciones', op, 'jsonb')]);
const corridaDe = r => (r.corridas || []).map(c => c.corrida).find(Boolean);
const IGUAL_ARCH = ['p_archivo.nombre', 'p_archivo.sha256', 'p_archivo.bytes', 'p_archivo.filas', 'p_opciones'];
const parte = (cuenta, monto) => ({ corrida: ID.journal, cuenta, monto });
const pasos = [
  { nombre: 'ensayo_journal', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('journal') },
  { nombre: 'columna_raro', fn: 'fn_nomina_columna', igual: ['p.columna', 'p.clase'], args: () => llama('fn_nomina_columna', [A('p', { columna: 'ZZ Dato raro', clase: 'ignorar', nota: T.raro }, 'jsonb')]) },
  { nombre: 'ensayo_journal_2', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('journal') },
  { nombre: 'importar_journal', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('journal'),
    despues: r => { ID.journal = corridaDe(r); ID.persona = { uno: persona('ZZ Ayudante Uno'), dos: persona('ZZ Ayudante Dos'), tres: persona('ZZ Oficial Tres') }; } },
  { nombre: 'enlazar_uno', fn: 'fn_nomina_persona', igual: ['p.id', 'p.usuario_id', 'p.clase', 'p.confirmar'], args: () => llama('fn_nomina_persona', [A('p', { id: ID.persona.uno, usuario_id: P_UNO, clase: 'campo', confirmar: true }, 'jsonb')]) },
  { nombre: 'enlazar_dos', fn: 'fn_nomina_persona', igual: ['p.id', 'p.usuario_id', 'p.clase', 'p.confirmar'], args: () => llama('fn_nomina_persona', [A('p', { id: ID.persona.dos, usuario_id: P_DOS, clase: 'campo', confirmar: true }, 'jsonb')]) },
  { nombre: 'enlazar_tres', fn: 'fn_nomina_persona', igual: ['p.id', 'p.usuario_id', 'p.clase', 'p.confirmar'], args: () => llama('fn_nomina_persona', [A('p', { id: ID.persona.tres, usuario_id: P_TRES, clase: 'oficial', confirmar: true }, 'jsonb')]) },
  { nombre: 'config_sin_obra', fn: 'fn_nomina_config', igual: ['p'], args: () => llama('fn_nomina_config', [A('p', { cuenta_sin_obra: '6000' }, 'jsonb')]) },
  { nombre: 'decidir_dos', fn: 'fn_nomina_decidir', igual: ['p_corrida', 'p_persona', 'p.decision'], args: () => llama('fn_nomina_decidir', [A('p_corrida', ID.journal, 'uuid'), A('p_persona', ID.persona.dos, 'uuid'), A('p', { decision: 'sin_obra', nota: T.dos }, 'jsonb')]) },
  { nombre: 'postear_journal', fn: 'fn_nomina_postear', igual: ['p_corrida', 'p_visto'], args: () => llama('fn_nomina_postear', [A('p_corrida', ID.journal, 'uuid'), A('p_visto', uno(`select fn_nomina_propuesta(${q(ID.journal)}::uuid)->>'visto'`))]) },
  { nombre: 'casar_net', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.net, 'uuid'), A('p_partes', [parte('2210', '4874.93')], 'jsonb'), A('p_nota', null)]) },
  { nombre: 'casar_tax', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.tax, 'uuid'), A('p_partes', [parte('2220', '1391.64'), parte('2225', '34.85'), parte('2230', '156.82')], 'jsonb'), A('p_nota', null)]) },
  { nombre: 'cuota_fee', fn: 'fn_nomina_cargo_cuota', igual: ['p_movimiento'], args: () => llama('fn_nomina_cargo_cuota', [A('p_movimiento', MOV.fee, 'uuid'), A('p_nota', null)]) },
  { nombre: 'casar_csd', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.csd, 'uuid'), A('p_partes', [parte('2240', '50.00')], 'jsonb'), A('p_nota', null)]),
    despues: r => { ID.pago_csd = r.pago; } },
  { nombre: 'deshacer_csd', fn: 'fn_nomina_cargo_deshacer', igual: ['p_pago'], args: () => llama('fn_nomina_cargo_deshacer', [A('p_pago', ID.pago_csd, 'uuid'), A('p_motivo', T.deshacer)]) },
  { nombre: 'ensayo_ya', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('journal') },
  { nombre: 'importar_ya', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('journal') },
  { nombre: 'ensayo_bono', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('bono') },
  { nombre: 'importar_bono', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('bono'), despues: r => { ID.bono = corridaDe(r); } },
  { nombre: 'postear_bono', fn: 'fn_nomina_postear', igual: ['p_corrida', 'p_visto'], args: () => llama('fn_nomina_postear', [A('p_corrida', ID.bono, 'uuid'), A('p_visto', uno(`select fn_nomina_propuesta(${q(ID.bono)}::uuid)->>'visto'`))]) },
  { nombre: 'anular_bono', fn: 'fn_nomina_anular', igual: ['p_corrida'], args: () => llama('fn_nomina_anular', [A('p_corrida', ID.bono, 'uuid'), A('p_motivo', T.anular)]) },
  { nombre: 'ensayo_otra', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('otra') },
  { nombre: 'importar_otra', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('otra') },
  { nombre: 'importar_otra_nomina', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('otra', { otra_nomina: true }), despues: r => { ID.otra = corridaDe(r); } },
  { nombre: 'descartar_otra', fn: 'fn_nomina_descartar', igual: ['p_corrida'], args: () => llama('fn_nomina_descartar', [A('p_corrida', ID.otra, 'uuid'), A('p_motivo', T.descartar)]) },
  { nombre: 'lote_1', fn: 'fn_nomina_lote', igual: ['p_desde', 'p_hasta'], args: () => llama('fn_nomina_lote', [A('p_desde', '2026-10-05', 'date'), A('p_hasta', '2026-10-18', 'date'), A('p_nota', T.lote)]), despues: r => { ID.lote_1 = r.lote; } },
  // (no lo hace la pantalla: en la app se aprueban después las 3 h del 17-oct de ZZ Ayudante Uno; el lote ya no es el de hoy)
  { nombre: 'aprobar_hora', externo: `update horas set aprobado_por = '${DUENO}', aprobado_el = '2026-10-21 15:00+00' where id = -1510000110;` },
  { nombre: 'lote_2', fn: 'fn_nomina_lote', igual: ['p_desde', 'p_hasta'], args: () => llama('fn_nomina_lote', [A('p_desde', '2026-10-05', 'date'), A('p_hasta', '2026-10-18', 'date'), A('p_nota', null)]), despues: r => { ID.lote_2 = r.lote; } },
  { nombre: 'declaracion_941', fn: 'fn_nomina_declaracion', igual: ['p.forma', 'p.anio', 'p.trimestre'], args: () => llama('fn_nomina_declaracion', [A('p', { forma: '941', anio: 2026, trimestre: 4, salarios: '5808.00', retencion: '503.00', ss_medicare: '888.60' }, 'jsonb')]) },
  { nombre: 'declaracion_940', fn: 'fn_nomina_declaracion', igual: ['p.forma', 'p.anio'], args: () => llama('fn_nomina_declaracion', [A('p', { forma: '940', anio: 2026, salarios: '5808.00', futa: '34.85' }, 'jsonb')]) },
  { nombre: 'declaracion_rt6', fn: 'fn_nomina_declaracion', igual: ['p.forma', 'p.anio', 'p.trimestre'], args: () => llama('fn_nomina_declaracion', [A('p', { forma: 'rt6', anio: 2026, trimestre: 4, salarios: '5800.00', contribucion: '156.82' }, 'jsonb')]) },
  { nombre: 'persona_tres', fn: 'fn_nomina_persona', igual: ['p.id', 'p.horas_periodo'], args: () => llama('fn_nomina_persona', [A('p', { id: ID.persona.tres, clase: 'oficial', a_obra: true, horas_periodo: '86', nota: 'ZZ: su sueldo cubre 86 h por quincena', activo: true }, 'jsonb')]) },
  { nombre: 'config', fn: 'fn_nomina_config', igual: ['p.semana_empieza', 'p.amarre_tolerancia'], args: () => llama('fn_nomina_config', [A('p', CFG, 'jsonb')]) },
  { nombre: 'columna_quitar', fn: 'fn_nomina_columna', igual: ['p.columna', 'p.quitar'], args: () => llama('fn_nomina_columna', [A('p', { columna: 'zz dato raro', quitar: true }, 'jsonb')]) }
];
// la configuración como la manda el formulario de Ajustes (todas sus claves; los números, como texto)
const CFG = { cuenta_sin_obra: '6000', cuenta_oficina: '6000', cuenta_oficial: '6005', cuenta_bolsa: '5015', cuenta_burden_obra: '5010', cuenta_burden_admin: '6010', cuenta_cuota: '6500',
  semana_empieza: 1, horas_extra_desde: '40', horas_periodo_oficial: '80', cargo_dias_antes: 10, cargo_dias_despues: 5, saldo_dias: 10, amarre_tolerancia: '2.00' };

// ---------- 6. los errores que la pantalla enseña (cada uno en su sesión, que se deshace entera) ----------
const errores = [
  { nombre: 'ensayo_sin_codigo', antes: null, aal: 'aal1', args: ensayo('journal') },
  { nombre: 'equipo_config', antes: null, quien: 'equipo', args: () => llama('fn_nomina_config', [A('p', null, 'jsonb')]) },
  { nombre: 'equipo_ensayo', antes: null, quien: 'equipo', args: ensayo('journal') },
  { nombre: 'persona_sin_codigo', antes: 'importar_journal', aal: 'aal1', args: () => llama('fn_nomina_persona', [A('p', { id: ID.persona.uno, usuario_id: P_UNO, clase: 'campo', confirmar: true }, 'jsonb')]) },
  { nombre: 'propuesta_sin_codigo', antes: 'importar_journal', aal: 'aal1', args: () => llama('fn_nomina_propuesta', [A('p_corrida', ID.journal, 'uuid')]) },
  { nombre: 'postear_visto_viejo', antes: 'decidir_dos', args: () => llama('fn_nomina_postear', [A('p_corrida', ID.journal, 'uuid'), A('p_visto', '0'.repeat(32))]) },
  { nombre: 'config_mal', antes: 'decidir_dos', args: () => llama('fn_nomina_config', [A('p', { ...CFG, semana_empieza: 9 }, 'jsonb')]) },
  { nombre: 'anular_con_cargos', antes: 'casar_net', args: () => llama('fn_nomina_anular', [A('p_corrida', ID.journal, 'uuid'), A('p_motivo', 'ZZ: prueba')]) },
  { nombre: 'deshacer_sin_motivo', antes: 'casar_csd', args: () => llama('fn_nomina_cargo_deshacer', [A('p_pago', ID.pago_csd, 'uuid'), A('p_motivo', '')]) },
  { nombre: 'anular_sin_motivo', antes: 'postear_bono', args: () => llama('fn_nomina_anular', [A('p_corrida', ID.bono, 'uuid'), A('p_motivo', '')]) },
  { nombre: 'lote_vacio', antes: 'descartar_otra', args: () => llama('fn_nomina_lote', [A('p_desde', '2026-09-01', 'date'), A('p_hasta', '2026-09-14', 'date'), A('p_nota', null)]) },
  { nombre: 'declaracion_mal', antes: 'lote_2', args: () => llama('fn_nomina_declaracion', [A('p', { forma: '941', anio: 2026, trimestre: 4, salarios: '58o8.00', retencion: '503.00', ss_medicare: '888.60' }, 'jsonb')]) }
];

function cadena() {
  const acumulado = {}, escenas = [escena(acumulado)], P = {}, E = {};
  const correrErrores = antes => {
    for (const e of errores.filter(x => x.antes === antes)) {
      const a = e.args();
      const [r] = pedir([{ sql: `select to_jsonb(${a.sql})`, quien: e.quien, aal: e.aal }], 'rollback');
      if (!r || !r.ERROR) throw new Error(`«${e.nombre}» no dio error: ${JSON.stringify(r).slice(0, 200)}`);
      E[e.nombre] = { fn: a.sql.slice(0, a.sql.indexOf('(')), args: a.json, ...comoPostgrest(r) };
    }
  };
  correrErrores(null);
  for (const p of pasos) {
    if (p.externo) {
      psql(p.externo);
      P[p.nombre] = { externo: true };
    } else {
      const a = p.args();
      const [r] = pedir([{ sql: `select to_jsonb(${a.sql})` }]);
      if (r && r.ERROR) throw new Error(`el paso «${p.nombre}» dio ${r.ERROR}: ${r.message}`);
      if (p.despues) p.despues(r);
      P[p.nombre] = { fn: p.fn, args: a.json, igual: p.igual, respuesta: r };
    }
    escenas.push(escena(acumulado, p.nombre));
    console.log(`  ${p.nombre}: ${Object.keys(escenas[escenas.length - 1].lecturas).length} lectura(s) cambiaron`);
    correrErrores(p.nombre);
  }
  return { escenas, pasos: P, orden: pasos.map(p => p.nombre), errores: E };
}

// ---------- 7. correr y escribir ----------
const hoy = JSON.parse(psql(`select to_jsonb(fn_fecha_miami(now()))::text;`).trim());
const c15 = cadena();
// lo que se esperaba de cada paso, en llano (si el banco contesta otra cosa, este script lo dice y para)
const res = n => c15.pasos[n].respuesta;
const debe = (cond, msg) => { if (!cond) throw new Error('el banco no contestó lo esperado: ' + msg); };
debe(res('ensayo_journal').corridas[0].sin_clasificar.length === 1 && res('ensayo_journal_2').corridas[0].sin_clasificar.length === 0, 'la columna rara: sin clasificar y después no');
debe(res('importar_journal').corridas[0].resultado === 'nueva' && res('importar_ya').corridas[0].resultado === 'ya_estaba', 'el journal: nueva y después ya_estaba');
debe(res('postear_journal').posteada === true && res('postear_bono').posteada === true && res('anular_bono').anulada === true, 'postear y anular');
debe(res('importar_otra').corridas[0].resultado === 'otra_distinta' && res('importar_otra_nomina').corridas[0].resultado === 'nueva', 'la otra nómina del mismo día');
debe(res('deshacer_csd').deshecho === true && res('cuota_fee').clase === 'cuota', 'deshacer y la cuota');
// nada delicado en lo que contestó el banco ni en lo que se le mandó (solo en los archivos que sube la prueba)
const sinArchivos = JSON.stringify({ FILAS, c15 });
for (const t of ['000-00-0001', '000-00-0002', '000-00-0003', '000-00-0009', 'Calle Falsa', '"SSN"', 'Home address', 'ZZ Nota']) {
  if (sinArchivos.includes(t)) throw new Error(`«${t}» salió en lo que se mandó o en lo que contestó el banco: no puede ser`);
}
const salida = {
  _leeme: 'La base simulada de «Nómina» (c15) que usa pantalla.js: lo que contestó el banco. La genera pruebas/conta/f15-capturar.js; no se edita a mano. Datos inventados (ZZ y C15 PRUEBA); las columnas delicadas de los archivos son de mentira (000-00-000N no existe).',
  capturado: { hoy, plantilla: PLANTILLA, c15: crypto.createHash('sha1').update(fs.readFileSync(path.join(ROOT, 'docs/conta/c15-nomina.sql'))).digest('hex').slice(0, 12),
    semilla: crypto.createHash('sha1').update(fs.readFileSync(path.join(__dirname, 'f15-semilla.sql'))).digest('hex').slice(0, 12) },
  ids: { ...ID, rangos: RANGOS },
  textos: { ...T, cfg: CFG },
  archivos: Object.fromEntries(Object.entries(ARCHIVOS).map(([k, a]) => [k, { nombre: a.nombre, texto: a.texto, sha256: sha(a.texto) }])),
  filas: FILAS, c15
};
fs.writeFileSync(SALIDA, JSON.stringify(salida) + '\n');
const kb = (fs.statSync(SALIDA).size / 1024).toFixed(0);
console.log(`listo: ${path.relative(ROOT, SALIDA)} (${kb} KB, ${Object.keys(FILAS).length} filas; ${c15.escenas.length} escenas y ${Object.keys(c15.errores).length} errores)`);
