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
        casar los cargos —los impuestos en dos cargos: el que ninguna opción
        casa se dice a mano—, la misma nómina leída de otras columnas, el
        bono, la otra nómina del mismo día, el lote de horas, el amarre…), y
        tras cada paso lo vuelve a leer todo (la escena
        siguiente). Un paso «externo» es algo que no hace la pantalla (una hora
        que se aprueba en la app después del lote);
     3. prueba, sin dejar nada, los errores que la pantalla enseña (sin el
        código del teléfono, el equipo, lo visto que ya cambió, un cargo ya
        casado, un monto mal escrito, las partes de un cargo que no lo suman…);
     4. escribe pruebas/conta/pantalla-f15.json: cada fila una vez (por su
        huella), de cada escena solo lo que cambió respecto de la anterior, y
        los SIETE ARCHIVOS que sube la prueba (los CSV sintéticos, con sus
        columnas delicadas DE MENTIRA: «SSN» 000-00-000N, que no existe, y
        «Home address» en una calle falsa). Lo que la pantalla manda de ellos
        es lo que este script manda: las celdas como texto, SIN las columnas
        delicadas (las de clase «delicado» del mapeo y la que trae algo con
        forma de Seguro Social), con la misma regla que js/conta.js
        (nominaLimpiar); pantalla.js compara las dos, celda por celda.
   (Arreglos del 13-nov, con la base arreglada) la cadena sigue además: la
   misma nómina leída de otras columnas que solo entra como «otra» con su
   porqué (y se descarta); dos bonos iguales del mismo día (el segundo, de
   otras columnas: «otra» con su porqué; posteado, el primero se frena por
   «repetida» hasta decir por qué es otro); una corrección de Gusto que
   DEVUELVE (con una columna que el mapeo no conoce: entra frenada, se dice
   qué es y se vuelve a leer «en su lugar»), que deja dinero A FAVOR y se casa
   con los dos depósitos de Gusto (el neto con su opción en negativo; los
   impuestos a mano, en negativo); un cargo casado que se des-casa en la
   Bandeja y se deshace aquí; la cuota sindical pagada por fuera de Gusto; y
   la bolsa del burden real (la prima de WC) repartida a las obras. Y cada
   escena se lee también SIN el código del teléfono (las claves «@aal1»): lo
   que la base deja ver sin él.
   (Revisión final, 13-nov) y, FUERA de la cadena, con la base como quedó al
   final y sin dejar nada («extras»): el asiento del journal en los Estados
   con lo que la vista sellada de los papeles dice de él y su papel de verdad
   (v_nomina_papel, con y sin el código), y un archivo SIN día de pago (y con
   una columna «Home phone» que el mapeo no conoce: no sale del navegador): el
   MX009 de la base, lo que contesta con el día dicho y lo que contesta
   importarlo así.
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
// la MISMA nómina del 23-oct bajada otra vez de Gusto con otras columnas (sin el desglose del bruto: solo «Gross earnings»): el mismo
// bruto y el mismo neto, leídos de otras columnas (la base no la da por igual: su firma va por concepto). No se sube como otra.
const SIN_DESGLOSE = ['Regular earnings', 'Overtime earnings'].map(c => CAB.indexOf(c));
const sinDesglose = l => l.split(',').filter((x, j) => !SIN_DESGLOSE.includes(j)).join(',');
const MISMA = [sinDesglose(CAB.join(',')), ...FILAS_J.map(sinDesglose), sinDesglose(TOT_J)].join('\n') + '\n';
// (arreglos) el MISMO bono bajado de otra forma (sin la columna «Bonus»: solo «Gross earnings»): las mismas personas con su mismo bruto
// y su mismo neto; aquí son DOS bonos iguales de verdad, y el segundo se sube como otra nómina con su porqué
const BONO2 = ['Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Gross earnings,Employee federal income tax,' +
  'Employee social security tax,Employee medicare tax,Employee taxes,Net pay,Check amount,Employer social security tax,Employer medicare tax,Employer FUTA tax,Employer SUTA tax,Employer taxes',
  `ZZ Ayudante,Uno,${PER},Bonus,Direct Deposit,500.00,50.00,31.00,7.25,88.25,411.75,411.75,31.00,7.25,3.00,13.50,54.75`].join('\n') + '\n';
// (arreglos) una CORRECCIÓN de Gusto que devuelve lo que se le pagó de más a ZZ Ayudante Uno (bruto −100.00, retenido −17.65, neto
// −82.35, patronal −10.95), con su propio día de pago (el lunes 26), las horas en cero y una columna con cifras que el mapeo no conoce
// («ZZ Ajuste raro»): entra frenada; se dice qué es y se vuelve a leer en su lugar
const CORR = ['Employee first name,Employee last name,Pay period start,Pay period end,Check date,Payroll type,Payment method,Regular hours,Bonus,Gross earnings,' +
  'Employee federal income tax,Employee social security tax,Employee medicare tax,Employee taxes,Net pay,Check amount,Employer social security tax,Employer medicare tax,' +
  'Employer FUTA tax,Employer SUTA tax,Employer taxes,ZZ Ajuste raro',
  'ZZ Ayudante,Uno,10/05/2026,10/18/2026,10/26/2026,Correction,Direct Deposit,0.00,-100.00,-100.00,-10.00,-6.20,-1.45,-17.65,-82.35,-82.35,-6.20,-1.45,-0.60,-2.70,-10.95,4'].join('\n') + '\n';
// (revisión final) un archivo SIN día de pago en ninguna parte (el resumen solo), y con una columna que el mapeo no conoce y que por su
// nombre es un dato de la persona («Home phone», de mentira): la base no lo puede leer sola (MX009) hasta que se dice su día de pago;
// el teléfono no sale del navegador. No entra en la cadena: se ensaya y se importa fuera de ella, y se deshace.
const SINDIA = ['Employee,Home phone,Gross earnings,Employee taxes,Net pay', '"ZZ Ayudante Dos",555-0100,100.00,10.00,90.00'].join('\n') + '\n';
const ARCHIVOS = { journal: { nombre: 'zz-c15-journal-23oct.csv', texto: JOURNAL }, bono: { nombre: 'zz-c15-bono-23oct.csv', texto: BONO }, sindia: { nombre: 'zz-c15-sin-dia.csv', texto: SINDIA },
  otra: { nombre: 'zz-c15-journal-23oct-v2.csv', texto: OTRA }, misma: { nombre: 'zz-c15-journal-23oct-columnas.csv', texto: MISMA },
  bono2: { nombre: 'zz-c15-bono-23oct-otra-forma.csv', texto: BONO2 }, corr: { nombre: 'zz-c15-correccion-26oct.csv', texto: CORR } };

// LAS CELDAS, como las lee la pantalla (comillas, comas dentro, BOM, CRLF) y LO QUE NO SALE DEL TELÉFONO, con la regla de js/conta.js
// (nominaLimpiar): una cabecera es lo que la base toma por cabecera (una fila con una columna de persona y una de dinero que el
// mapeo conoce, y ninguna celda que sea una cifra); en cada sección se quitan las columnas de clase «delicado», las que el mapeo no
// conoce y por su NOMBRE son un dato de la persona y no dinero (su teléfono, su cuenta del banco…) y las de clase desconocida o
// «ignorar» que traigan algo con forma de Seguro Social (###-##-####); lo de antes de la primera cabecera (el preámbulo) se queda,
// sin esas celdas. Si una columna que SÍ se guarda trae esa forma, el archivo no se manda.
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
const CLASES_PERSONA = ['nombre', 'apellido', 'nombre_completo', 'empleado_id'];
const CLASES_DINERO = ['bruto', 'bruto_total', 'imp_empleado', 'imp_empleado_total', 'deduccion', 'deduccion_total', 'neto', 'reembolso', 'reembolso_total', 'cheque_total', 'imp_patron', 'imp_patron_total', 'ben_patron', 'ben_patron_total', 'costo_total'];
const esCifra = x => {
  let t = String(x == null ? '' : x).trim();
  if (/^[-—–]$/.test(t)) return true;
  if (/^\(.*\)$/.test(t)) t = t.slice(1, -1).trim();
  if (t[0] === '-') t = t.slice(1).trim();
  if (t[0] === '$') { t = t.slice(1).trim(); if (t[0] === '-') t = t.slice(1).trim(); }
  return t.length <= 40 && (/^[0-9]{1,3}(,[0-9]{3})+(\.[0-9]+)?$/.test(t) || /^[0-9]+(\.[0-9]+)?$/.test(t) || /^\.[0-9]+$/.test(t));
};
const esCab = (f, mapa) => {
  let per = false, din = false, cifra = false;
  for (const x of f) {
    const t = String(x == null ? '' : x).trim(); if (!t) continue;
    const k = mapa.get(norm(t));
    if (k) { per = per || CLASES_PERSONA.includes(k); din = din || CLASES_DINERO.includes(k); }
    else if (esCifra(t)) cifra = true;
  }
  return per && din && !cifra;
};
const NOMBRE_DELICADO = new RegExp('(^| )(ssn|itin|social security (number|no|num)|tax ?payer id|tax id|date of birth|birth ?date|dob|bank account|routing|account (number|no|num)|passport|driver s? ?license)( |$)'
  + '|(^| )birthday$|(^| )(home|mailing|residential|personal|employee|street) address( [a-z0-9]+)*$|^address( line)?( [0-9])?$|(^| )(zip|postal)( code)?$'
  + '|(^| )e ?mail( address)?$|(^| )(phone|telephone|mobile|cell)( phone)?( number| no| num)?$');
function limpiar(filas, mapa) {
  const cab = filas.map(f => esCab(f, mapa));
  const quitar = new Array(filas.length).fill(null).map(() => new Set());
  let ini = -1;
  const cerrar = (a, b) => {
    if (a < 0) return;
    const fuera = new Set();
    filas[a].forEach((x, j) => { const n = norm(x), k = mapa.get(n); if (k === 'delicado' || (!k && n && NOMBRE_DELICADO.test(n))) fuera.add(j); });
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
  if (/000-00-000|Calle Falsa|"SSN"|Home address|ZZ Nota|555-01|Home phone/.test(s)) throw new Error(`lo que se manda de «${k}» lleva algo delicado`);
}

// ---------- los ids que la prueba necesita ----------
// (los cinco cargos de Gusto de octubre; y, de los arreglos, los dos depósitos de Gusto de la corrección y la cuota sindical, que no es de Gusto)
const MOV = Object.fromEntries(['fee', 'net', 'tax', 'sui', 'csd', 'dev', 'dvt', 'sin'].map(k => [k, uno(`select id from movimientos_banco where id_externo = 'c15-pantalla-${k}'`)]));
const MOV_BJ = ['fee', 'net', 'tax', 'sui', 'csd'].map(k => MOV[k]);
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
  // (las cuentas del libro, como las lee la pantalla para nombrar cada línea del asiento: las de la nómina, con su nombre de c1)
  o.push({ k: 'cuentas', sql: 'select ' + filasDe(`select codigo, nombre, tipo, regla_obra, imputable, activa from cuentas order by codigo`) });
  // (lo que TODAS las nóminas posteadas dejaron por pagar: «decir a mano qué paga» un cargo de Gusto)
  o.push({ k: 'fn_nomina_pendiente|', sql: 'select ' + filasDe(`select * from fn_nomina_pendiente() order by dia_pago desc, cuenta`) });
  for (const c of corridas) {
    o.push({ k: `fn_nomina_propuesta|${c}`, sql: `select fn_nomina_propuesta(${q(c)}::uuid)` });
    o.push({ k: `fn_nomina_pendiente|${c}`, sql: 'select ' + filasDe(`select * from fn_nomina_pendiente(${q(c)}::uuid) order by cuenta`) });
  }
  for (const m of movs) o.push({ k: `fn_nomina_cargo_propuesta|${m}`, sql: `select fn_nomina_cargo_propuesta(${q(m)}::uuid)` });
  // (arreglos) los cargos del banco que no son de Gusto y pueden pagar lo que Gusto no cobra; la bolsa del burden real (el último mes
  // terminado, sin mes, y el de hoy, que no ha terminado)
  o.push({ k: 'fn_nomina_cargos_fuera|', sql: 'select ' + filasDe(`select * from fn_nomina_cargos_fuera()`) });
  o.push({ k: 'fn_nomina_bolsa|', sql: `select fn_nomina_bolsa(null)` });
  o.push({ k: 'fn_nomina_bolsa|2026-11', sql: `select fn_nomina_bolsa('2026-11')` });
  for (const [d, h] of RANGOS) o.push({ k: `fn_nomina_horas_gusto|${d}|${h}`, sql: 'select ' + filasDe(`select * from fn_nomina_horas_gusto('${d}', '${h}')`) });
  for (const l of lotes) o.push({ k: `fn_nomina_lote_csv|${l}`, sql: `select to_jsonb(fn_nomina_lote_csv(${q(l)}::uuid))` });
  // (las cuatro filas que la nómina le da al cierre del mes: c9 las pide con su bloque; la pantalla del cierre las lleva a «Nómina»)
  for (const p of ['2026-10', '2026-11']) o.push({ k: `fn_nomina_cierre|${p}`, sql: 'select ' + filasDe(`select * from fn_nomina_cierre('${p}') order by orden`) });
  // (la Bandeja del banco: las filas de los cargos de Gusto, como las da c6, para la tarjeta con «Casar con la nómina»)
  o.push({ k: 'v_banco_bandeja', sql: 'select ' + filasDe(`select * from v_banco_bandeja where movimiento_id in (${MOV_BJ.map(m => q(m) + '::uuid').join(', ')}) order by fecha, movimiento_id`) });
  return o;
}
// (arreglos) lo mismo SIN el código del teléfono (aal1): lo que la base deja ver sin él (sin corridas ni lo de nadie; el control que
// pide el código en lo que mira dinero). Solo las lecturas que la pantalla hace sin el código; las que lo exigen dan su error en la mentira.
const SIN_CODIGO = /^(v_nomina_control|v_nomina_corridas|v_nomina_personas|v_nomina_cargos|v_nomina_lotes|nomina_columnas|fn_nomina_config\||fn_nomina_amarre\||fn_nomina_pendiente\|$|fn_nomina_cargos_fuera\||fn_nomina_cierre\||fn_nomina_horas_gusto\|)/;

// ---------- 4. el almacén: cada fila una vez, por su huella ----------
const FILAS = {};
const huella = v => crypto.createHash('sha1').update(JSON.stringify(v)).digest('hex').slice(0, 12);
function guardar(v) {
  if (!Array.isArray(v)) return { valor: v };
  return { filas: v.map(f => { const h = huella(f); FILAS[h] = f; return h; }) };
}
function escena(acumulado, paso) {
  const lect = lecturas(), sin = lect.filter(x => SIN_CODIGO.test(x.k)).map(x => ({ ...x, k: x.k + '@aal1', aal: 'aal1' }));
  const todas = lect.concat(sin), r = pedir(todas.map(x => ({ sql: x.sql, aal: x.aal })));
  const cambia = {};
  todas.forEach((x, i) => {
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
  lote: 'ZZ: las horas de la quincena para Gusto',
  mano: 'ZZ: Gusto cobró los impuestos en dos cargos (el federal y el de Florida)',
  // (arreglos)
  porque_misma: 'ZZ: creí que era la del bono; no lo es',
  descartar_misma: 'ZZ: era la misma nómina bajada de otra forma',
  dos_bonos: 'ZZ: son dos bonos iguales, uno por cada obra',
  dos_bonos_1: 'ZZ: el otro bono, el de la obra A',
  ajuste: 'ZZ: una columna de control de Gusto; no es dinero',
  dev_mano: 'ZZ: Gusto devolvió los impuestos de la corrección en un depósito',
  descasar: 'ZZ: des-casado en la Bandeja por error',
  deshacer_sui: 'ZZ: se des-casó en la Bandeja; lo deshago aquí también',
  fuera: 'ZZ: la cuota sindical de octubre, pagada al sindicato'
};
const llama = (fn, args) => ({ sql: `${fn}(${args.map(a => a.sql).join(', ')})`, json: Object.fromEntries(args.map(a => [a.k, a.v])) });
const A = (k, v, tipo) => ({ k, v, sql: v == null ? 'null' : tipo === 'jsonb' ? jb(v) : tipo === 'uuid' ? `${q(v)}::uuid` : tipo === 'date' ? `${q(v)}::date` : tipo === 'int' ? String(v) : q(v) });
const ensayo = (k, op = {}) => () => llama('fn_nomina_ensayo', [A('p_archivo', enviar(k), 'jsonb'), A('p_opciones', op, 'jsonb')]);
const importar = (k, op = {}) => () => llama('fn_nomina_importar', [A('p_archivo', enviar(k), 'jsonb'), A('p_opciones', op, 'jsonb')]);
const corridaDe = r => (r.corridas || []).map(c => c.corrida).find(Boolean);
const IGUAL_ARCH = ['p_archivo.nombre', 'p_archivo.sha256', 'p_archivo.bytes', 'p_archivo.filas', 'p_opciones'];
const parte = (cuenta, monto, corrida) => ({ corrida: corrida || ID.journal, cuenta, monto });
// (arreglos) el amarre: lo que el libro dice hoy de cada renglón (lo que Edgar teclea sale de ahí: igual, o con la diferencia de la prueba)
const libro = (forma, campo) => uno(`select libro::text from fn_nomina_amarre(2026) where forma = ${q(forma)} and campo = ${q(campo)} and (trimestre = 4 or trimestre is null) limit 1`);
const menos = (v, d) => (Math.round(Number(v) * 100) - Math.round(d * 100)) / 100;
const dosDec = v => (Math.round(Number(v) * 100) / 100).toFixed(2);
const propuestaDe = (mov, i = 0) => uno(`select fn_nomina_cargo_propuesta(${q(mov)}::uuid)->'opciones'->${i}->'partes'`);
const pagoDe = mov => uno(`select id from nomina_pagos where movimiento_id = ${q(mov)}::uuid and estado = 'aplicado'`);
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
  // (los impuestos en dos cargos: el federal con el FUTA no casa al centavo con ninguna opción y se dice a mano; después, el de Florida
  // sí casa: lo único que queda por pagar de impuestos)
  { nombre: 'casar_tax_mano', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes', 'p_nota'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.tax, 'uuid'), A('p_partes', [parte('2220', '1391.64'), parte('2225', '34.85')], 'jsonb'), A('p_nota', T.mano)]) },
  { nombre: 'casar_sui', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.sui, 'uuid'), A('p_partes', [parte('2230', '156.82')], 'jsonb'), A('p_nota', null)]),
    despues: r => { ID.pago_sui = r.pago; } },
  { nombre: 'cuota_fee', fn: 'fn_nomina_cargo_cuota', igual: ['p_movimiento'], args: () => llama('fn_nomina_cargo_cuota', [A('p_movimiento', MOV.fee, 'uuid'), A('p_nota', null)]) },
  { nombre: 'casar_csd', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.csd, 'uuid'), A('p_partes', [parte('2240', '50.00')], 'jsonb'), A('p_nota', null)]),
    despues: r => { ID.pago_csd = r.pago; } },
  { nombre: 'deshacer_csd', fn: 'fn_nomina_cargo_deshacer', igual: ['p_pago'], args: () => llama('fn_nomina_cargo_deshacer', [A('p_pago', ID.pago_csd, 'uuid'), A('p_motivo', T.deshacer)]) },
  { nombre: 'ensayo_ya', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('journal') },
  { nombre: 'importar_ya', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('journal') },
  { nombre: 'ensayo_misma', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('misma') },
  { nombre: 'importar_misma', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('misma') },
  // (arreglos) la misma nómina de otras columnas solo entra como «otra» con su porqué; abierta, se ve que es la misma y se descarta
  { nombre: 'importar_misma_porque', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('misma', { otra_nomina: true, otra_porque: T.porque_misma }), despues: r => { ID.misma = corridaDe(r); } },
  { nombre: 'descartar_misma', fn: 'fn_nomina_descartar', igual: ['p_corrida'], args: () => llama('fn_nomina_descartar', [A('p_corrida', ID.misma, 'uuid'), A('p_motivo', T.descartar_misma)]) },
  { nombre: 'ensayo_bono', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('bono') },
  { nombre: 'importar_bono', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('bono'), despues: r => { ID.bono = corridaDe(r); } },
  // (arreglos) el segundo bono, igual, bajado de otra forma: la base ofrece reemplazar al primero (sin postear) o subirlo como otro con
  // su porqué; es otro. Posteado él, el primero se frena por «repetida» hasta decir por qué es otro
  { nombre: 'ensayo_bono2', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('bono2') },
  { nombre: 'importar_bono2', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('bono2') },
  { nombre: 'importar_bono2_porque', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('bono2', { otra_nomina: true, otra_porque: T.dos_bonos }), despues: r => { ID.bono2 = corridaDe(r); } },
  { nombre: 'postear_bono2', fn: 'fn_nomina_postear', igual: ['p_corrida', 'p_visto'], args: () => llama('fn_nomina_postear', [A('p_corrida', ID.bono2, 'uuid'), A('p_visto', uno(`select fn_nomina_propuesta(${q(ID.bono2)}::uuid)->>'visto'`))]) },
  { nombre: 'porque_bono', fn: 'fn_nomina_corrida', igual: ['p_corrida', 'p.otra_porque'], args: () => llama('fn_nomina_corrida', [A('p_corrida', ID.bono, 'uuid'), A('p', { otra_porque: T.dos_bonos_1 }, 'jsonb')]) },
  { nombre: 'postear_bono', fn: 'fn_nomina_postear', igual: ['p_corrida', 'p_visto'], args: () => llama('fn_nomina_postear', [A('p_corrida', ID.bono, 'uuid'), A('p_visto', uno(`select fn_nomina_propuesta(${q(ID.bono)}::uuid)->>'visto'`))]) },
  { nombre: 'anular_bono', fn: 'fn_nomina_anular', igual: ['p_corrida'], args: () => llama('fn_nomina_anular', [A('p_corrida', ID.bono, 'uuid'), A('p_motivo', T.anular)]) },
  { nombre: 'ensayo_otra', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('otra') },
  { nombre: 'importar_otra', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('otra') },
  { nombre: 'importar_otra_nomina', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('otra', { otra_nomina: true }), despues: r => { ID.otra = corridaDe(r); } },
  { nombre: 'descartar_otra', fn: 'fn_nomina_descartar', igual: ['p_corrida'], args: () => llama('fn_nomina_descartar', [A('p_corrida', ID.otra, 'uuid'), A('p_motivo', T.descartar)]) },
  // (arreglos) LA CORRECCIÓN que devuelve: entra frenada (una columna que el mapeo no conoce); se vuelve a subir, se dice qué es y se
  // vuelve a leer en su lugar; posteada deja dinero A FAVOR, que se casa con los dos depósitos de Gusto (el neto con su opción, los
  // impuestos a mano, todo en negativo)
  { nombre: 'ensayo_corr', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('corr') },
  { nombre: 'importar_corr', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('corr'), despues: r => { ID.corr1 = corridaDe(r); } },
  { nombre: 'ensayo_corr_2', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('corr') },
  { nombre: 'columna_ajuste', fn: 'fn_nomina_columna', igual: ['p.columna', 'p.clase'], args: () => llama('fn_nomina_columna', [A('p', { columna: 'ZZ Ajuste raro', clase: 'ignorar', nota: T.ajuste }, 'jsonb')]) },
  { nombre: 'ensayo_corr_3', fn: 'fn_nomina_ensayo', igual: IGUAL_ARCH, args: ensayo('corr') },
  { nombre: 'importar_corr_ya', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('corr') },
  { nombre: 'importar_corr_reemplazar', fn: 'fn_nomina_importar', igual: IGUAL_ARCH, args: importar('corr', { reemplazar: true }), despues: r => { ID.corr = corridaDe(r); } },
  { nombre: 'postear_corr', fn: 'fn_nomina_postear', igual: ['p_corrida', 'p_visto'], args: () => llama('fn_nomina_postear', [A('p_corrida', ID.corr, 'uuid'), A('p_visto', uno(`select fn_nomina_propuesta(${q(ID.corr)}::uuid)->>'visto'`))]) },
  { nombre: 'casar_dev', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.dev, 'uuid'), A('p_partes', (propuestaDe(MOV.dev) || []).map(x => ({ corrida: x.corrida, cuenta: x.cuenta, monto: dosDec(x.monto) })), 'jsonb'), A('p_nota', null)]) },
  { nombre: 'casar_dvt_mano', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes', 'p_nota'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.dvt, 'uuid'), A('p_partes', [parte('2220', '-25.30', ID.corr), parte('2225', '-0.60', ID.corr), parte('2230', '-2.70', ID.corr)], 'jsonb'), A('p_nota', T.dev_mano)]) },
  // (arreglos) un cargo casado aquí que se des-casa en la Bandeja del banco (no lo hace la página de la nómina): sale «descasado» y se deshace aquí; después se casa otra vez
  { nombre: 'descasar_sui', externo: `begin; select set_config('request.jwt.claims', json_build_object('sub', '${DUENO}', 'role', 'authenticated', 'aal', 'aal2')::text, true), set_config('request.jwt.claim.sub', '${DUENO}', true); set local role authenticated; select fn_banco_descasar('${MOV.sui}'::uuid, ${q(T.descasar)}); commit;` },
  { nombre: 'deshacer_sui', fn: 'fn_nomina_cargo_deshacer', igual: ['p_pago'], args: () => llama('fn_nomina_cargo_deshacer', [A('p_pago', ID.pago_sui, 'uuid'), A('p_motivo', T.deshacer_sui)]) },
  { nombre: 'casar_sui_2', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.sui, 'uuid'), A('p_partes', [parte('2230', '156.82')], 'jsonb'), A('p_nota', null)]) },
  // (arreglos) la cuota sindical (lo retenido en deducciones), pagada al sindicato por fuera de Gusto: con su nota
  { nombre: 'casar_fuera', fn: 'fn_nomina_cargo_casar', igual: ['p_movimiento', 'p_partes', 'p_nota'], args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.sin, 'uuid'), A('p_partes', [parte('2240', '50.00')], 'jsonb'), A('p_nota', T.fuera)]) },
  { nombre: 'lote_1', fn: 'fn_nomina_lote', igual: ['p_desde', 'p_hasta'], args: () => llama('fn_nomina_lote', [A('p_desde', '2026-10-05', 'date'), A('p_hasta', '2026-10-18', 'date'), A('p_nota', T.lote)]), despues: r => { ID.lote_1 = r.lote; } },
  // (no lo hace la pantalla: en la app se aprueban después las 3 h del 17-oct de ZZ Ayudante Uno; el lote ya no es el de hoy)
  { nombre: 'aprobar_hora', externo: `update horas set aprobado_por = '${DUENO}', aprobado_el = '2026-10-21 15:00+00' where id = -1510000110;` },
  { nombre: 'lote_2', fn: 'fn_nomina_lote', igual: ['p_desde', 'p_hasta'], args: () => llama('fn_nomina_lote', [A('p_desde', '2026-10-05', 'date'), A('p_hasta', '2026-10-18', 'date'), A('p_nota', null)]), despues: r => { ID.lote_2 = r.lote; } },
  // (lo que Edgar teclea: lo del libro, salvo Social Security y Medicare del 941 con 4 centavos de menos —amarra: dentro de la tolerancia— y
  // los salarios del RT-6 con 8 dólares de menos —no amarra—)
  { nombre: 'declaracion_941', fn: 'fn_nomina_declaracion', igual: ['p.forma', 'p.anio', 'p.trimestre'], args: () => llama('fn_nomina_declaracion', [A('p', { forma: '941', anio: 2026, trimestre: 4, salarios: dosDec(libro('941', 'salarios')), retencion: dosDec(libro('941', 'retencion')), ss_medicare: dosDec(menos(libro('941', 'ss_medicare'), 0.04)) }, 'jsonb')]) },
  { nombre: 'declaracion_940', fn: 'fn_nomina_declaracion', igual: ['p.forma', 'p.anio'], args: () => llama('fn_nomina_declaracion', [A('p', { forma: '940', anio: 2026, salarios: dosDec(libro('940', 'salarios')), futa: dosDec(libro('940', 'futa')) }, 'jsonb')]) },
  { nombre: 'declaracion_rt6', fn: 'fn_nomina_declaracion', igual: ['p.forma', 'p.anio', 'p.trimestre'], args: () => llama('fn_nomina_declaracion', [A('p', { forma: 'rt6', anio: 2026, trimestre: 4, salarios: dosDec(menos(libro('rt6', 'salarios'), 8)), contribucion: dosDec(libro('rt6', 'contribucion')) }, 'jsonb')]) },
  { nombre: 'persona_tres', fn: 'fn_nomina_persona', igual: ['p.id', 'p.horas_periodo'], args: () => llama('fn_nomina_persona', [A('p', { id: ID.persona.tres, clase: 'oficial', a_obra: true, horas_periodo: '86', nota: 'ZZ: su sueldo cubre 86 h por quincena', activo: true }, 'jsonb')]) },
  { nombre: 'config', fn: 'fn_nomina_config', igual: ['p.semana_empieza', 'p.amarre_tolerancia'], args: () => llama('fn_nomina_config', [A('p', CFG, 'jsonb')]) },
  // (arreglos) la bolsa del burden real: lo que dejó la prima de WC de octubre, repartido a las obras por las horas que la nómina pagó
  { nombre: 'bolsa_repartir', fn: 'fn_nomina_bolsa_repartir', igual: ['p_mes', 'p_visto'], args: () => llama('fn_nomina_bolsa_repartir', [A('p_mes', '2026-10'), A('p_visto', uno(`select fn_nomina_bolsa('2026-10')->>'visto'`))]) },
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
  { nombre: 'casar_mano_suma', antes: 'casar_net', args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.tax, 'uuid'), A('p_partes', [parte('2220', '1391.64'), parte('2225', '34.58')], 'jsonb'), A('p_nota', T.mano)]) },
  { nombre: 'anular_con_cargos', antes: 'casar_net', args: () => llama('fn_nomina_anular', [A('p_corrida', ID.journal, 'uuid'), A('p_motivo', 'ZZ: prueba')]) },
  { nombre: 'deshacer_sin_motivo', antes: 'casar_csd', args: () => llama('fn_nomina_cargo_deshacer', [A('p_pago', ID.pago_csd, 'uuid'), A('p_motivo', '')]) },
  { nombre: 'anular_sin_motivo', antes: 'postear_bono', args: () => llama('fn_nomina_anular', [A('p_corrida', ID.bono, 'uuid'), A('p_motivo', '')]) },
  { nombre: 'lote_vacio', antes: 'descartar_otra', args: () => llama('fn_nomina_lote', [A('p_desde', '2026-09-01', 'date'), A('p_hasta', '2026-09-14', 'date'), A('p_nota', null)]) },
  // (arreglos) el porqué de «otra nómina» demasiado corto; casar por fuera de Gusto sin la nota; repartir la bolsa con lo visto que cambió
  { nombre: 'importar_porque_corto', antes: 'importar_misma', args: importar('misma', { otra_nomina: true, otra_porque: 'zz' }) },
  { nombre: 'casar_fuera_sin_nota', antes: 'casar_sui_2', args: () => llama('fn_nomina_cargo_casar', [A('p_movimiento', MOV.sin, 'uuid'), A('p_partes', [parte('2240', '50.00')], 'jsonb'), A('p_nota', null)]) },
  { nombre: 'bolsa_visto_viejo', antes: 'config', args: () => llama('fn_nomina_bolsa_repartir', [A('p_mes', '2026-10'), A('p_visto', '0'.repeat(32))]) },
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
// (lo que se leyó en la escena de después de un paso)
const leidoTras = (paso, k) => { for (let i = c15.orden.indexOf(paso) + 1; i >= 0; i--) { const l = c15.escenas[i].lecturas[k]; if (l) return l.filas ? l.filas.map(h => FILAS[h]) : l.valor; } };
debe(leidoTras('casar_net', `fn_nomina_cargo_propuesta|${MOV.tax}`).opciones.length === 0 && leidoTras('casar_tax_mano', `fn_nomina_cargo_propuesta|${MOV.sui}`).opciones.length === 1 &&
  res('casar_tax_mano').ya_estaba === false && res('casar_sui').ya_estaba === false, 'los impuestos en dos cargos: el federal no casa solo (a mano) y el de Florida, después, sí');
{ const e = res('ensayo_misma').corridas[0];
  debe(e.ya_estaba && e.ya_estaba.mismas_cifras === false && Number(e.totales.bruto) === Number(e.ya_estaba.bruto) && Number(e.totales.neto) === Number(e.ya_estaba.neto) &&
    res('importar_misma').corridas[0].resultado === 'otra_distinta', 'la misma nómina con otras columnas: otra_distinta, con el mismo bruto y el mismo neto'); }
debe(c15.errores.casar_mano_suma.error.code === 'MX001', 'las partes a mano que no suman el cargo: MX001');
// nada delicado en lo que contestó el banco ni en lo que se le mandó (solo en los archivos que sube la prueba)
// (arreglos) lo nuevo de la base, como se esperaba
{ const m = res('importar_misma').corridas[0], mp = res('importar_misma_porque').corridas[0];
  debe(m.resultado === 'otra_distinta' && m.misma === true && m.se_puede_otra === false && m.se_puede_reemplazar === false && mp.resultado === 'nueva',
    'la misma nómina de otras columnas: otra_distinta con misma (sin «otra» a secas ni reemplazar), y con su porqué entra'); }
{ const e = res('ensayo_bono2').corridas[0], b = res('importar_bono2').corridas[0];
  debe(e.ya_estaba && e.ya_estaba.misma === true && e.ya_estaba.se_puede_reemplazar === true && b.resultado === 'otra_distinta' && b.misma === true && b.se_puede_reemplazar === true &&
    res('importar_bono2_porque').corridas[0].resultado === 'nueva', 'el segundo bono: misma, se puede reemplazar; con su porqué entra');
  debe((leidoTras('postear_bono2', `fn_nomina_propuesta|${ID.bono}`).frenos || []).some(f => f.codigo === 'repetida') &&
    !(leidoTras('porque_bono', `fn_nomina_propuesta|${ID.bono}`).frenos || []).some(f => f.codigo === 'repetida') && res('porque_bono').otra_porque === T.dos_bonos_1,
    'el primer bono: frenado por «repetida» con el segundo posteado, y suelto al decir por qué'); }
{ const i1 = res('importar_corr').corridas[0], ya = res('importar_corr_ya').corridas[0], re = res('importar_corr_reemplazar').corridas[0];
  debe(i1.resultado === 'nueva' && res('ensayo_corr').corridas[0].sin_clasificar.length === 1 && res('ensayo_corr_3').corridas[0].ya_estaba.lee_distinto === true &&
    ya.resultado === 'ya_estaba' && ya.se_puede_reemplazar === true && re.resultado === 'reemplazada', 'la corrección: frenada, vuelta a leer en su lugar');
  const k = leidoTras('postear_corr', 'v_nomina_corridas').find(x => x.corrida_id === ID.corr);
  debe(k && Number(k.por_pagar) === 0 && Number(k.a_favor) === 110.95, 'la corrección posteada: nada por pagar y $110.95 a favor');
  debe(leidoTras('postear_corr', `fn_nomina_cargo_propuesta|${MOV.dev}`).opciones.some(o => o.partes.every(x => Number(x.monto) < 0)) && res('casar_dev').ya_estaba === false &&
    res('casar_dvt_mano').ya_estaba === false && res('casar_fuera').clase === 'fuera', 'los depósitos de Gusto en negativo y la cuota sindical por fuera'); }
debe(leidoTras('descasar_sui', 'v_nomina_cargos').some(x => x.estado === 'descasado' && x.movimiento_id === MOV.sui) && leidoTras('descasar_sui', 'v_nomina_cargos').some(x => x.estado === 'pendiente' && x.movimiento_id === MOV.sui),
  'el des-casado en la Bandeja: «descasado» y otra vez pendiente');
debe(leidoTras('deshacer_csd', 'fn_nomina_cargos_fuera|').some(x => x.movimiento_id === MOV.sin), 'la cuota sindical: candidata a pagada por fuera de Gusto');
debe(leidoTras('config', 'fn_nomina_bolsa|').puede === true && leidoTras('bolsa_repartir', 'fn_nomina_bolsa|').puede === false && leidoTras('config', 'fn_nomina_bolsa|2026-11').puede === false, 'la bolsa: se reparte una vez');
debe(leidoTras('postear_journal', 'v_nomina_corridas@aal1').length === 0 && leidoTras('postear_journal', 'v_nomina_control@aal1').some(x => x.ok === false && /hace falta el código del teléfono/.test(x.detalle)),
  'sin el código: ninguna corrida y el control que lo pide');
// ---------- 7b. (revisión final) lo que la pantalla lee o manda FUERA de la cadena, con la base como quedó al final (cada orden se deshace) ----------
//   · EL PAPEL DE UN ASIENTO DE LA NÓMINA en los Estados: las líneas del journal del 23-oct (v_libro), lo que la vista de los papeles de
//     c4/c6 dice de él («el papel ya no está»: está sellada y no conoce la nómina) y su papel de verdad (v_nomina_papel), con el código
//     del teléfono y sin él;
//   · EL ARCHIVO SIN DÍA DE PAGO: el error de la base (MX009), lo que contesta cuando se le dice el día, lo que contesta importarlo así
//     y —ya importado— lo que contesta ensayarlo OTRA VEZ diciendo otro día (ya está: sale del mismo archivo).
const leeComo = (consulta, aal = 'aal2') => pedir([{ sql: `select ${filasDe(consulta)}`, aal }], 'rollback')[0];
const valorDe = a => { const [r] = pedir([{ sql: `select to_jsonb(${a.sql})` }], 'rollback'); if (r && r.ERROR) throw new Error(`fuera de la cadena, ${a.sql.slice(0, 40)}… dio ${r.ERROR}: ${r.message}`); return r; };
const errorDe = a => { const [r] = pedir([{ sql: `select to_jsonb(${a.sql})` }], 'rollback'); if (!r || !r.ERROR) throw new Error(`fuera de la cadena, ${a.sql.slice(0, 40)}… no dio error`); return comoPostgrest(r); };
const ASIENTO_J = uno(`select asiento_id from nomina_corridas where id = ${q(ID.journal)}::uuid`);
const DIA_SIN = '2026-10-30', DIA_OTRO = '2026-11-13';
// (el mismo archivo sin fechas, ya importado con su día, ensayado OTRA VEZ diciendo otro día —dos semanas después—: en una sola
// transacción que se deshace, lo que contesta el ensayo)
// (y lo que contesta IMPORTARLO así —ya estaba, con otro día: la base dice «si de verdad es otra, súbela diciendo por qué»— y, dicho
// el porqué, que entra como otra nómina)
const PORQUE_OTRA = 'C15 PRUEBA: son dos nóminas iguales, de sueldo fijo';
const otraVez = () => { const r = pedir([{ sql: `select to_jsonb(${importar('sindia', { dia_pago: DIA_SIN })().sql})` }, { sql: `select to_jsonb(${ensayo('sindia', { dia_pago: DIA_OTRO })().sql})` },
    { sql: `select to_jsonb(${importar('sindia', { dia_pago: DIA_OTRO })().sql})` }, { sql: `select to_jsonb(${importar('sindia', { dia_pago: DIA_OTRO, otra_nomina: true, otra_porque: PORQUE_OTRA })().sql})` }], 'rollback');
  if (r.some(x => x && x.ERROR)) throw new Error(`fuera de la cadena, el archivo sin día otra vez dio ${JSON.stringify(r.find(x => x && x.ERROR)).slice(0, 200)}`);
  return { dia: DIA_OTRO, ensayo: r[1], importar: r[2], porque: PORQUE_OTRA, importar_porque: r[3] }; };
const PAPEL_NOM = `select origen_tabla, origen_id, papel, ruta from v_nomina_papel where origen_tabla = 'nomina_corridas' and origen_id = ${q(ID.journal)}`;
const extras = {
  papel: { asiento_id: ASIENTO_J, corrida: ID.journal,
    libro: leeComo(`select * from v_libro where asiento_id = ${q(ASIENTO_J)}::uuid order by orden`),
    asiento_papel: leeComo(`select * from v_asiento_papel where asiento_id = ${q(ASIENTO_J)}::uuid`),
    nomina_papel: { aal2: leeComo(PAPEL_NOM), aal1: leeComo(PAPEL_NOM, 'aal1') } },
  sin_dia: { dia: DIA_SIN, error: errorDe(ensayo('sindia')()), ensayo: valorDe(ensayo('sindia', { dia_pago: DIA_SIN })()), importar: valorDe(importar('sindia', { dia_pago: DIA_SIN })()),
    otra_vez: otraVez() }
};
debe(extras.papel.libro.length >= 2 && extras.papel.asiento_papel.length === 1 && extras.papel.asiento_papel[0].papel_existe === false && /el papel ya no está/.test(extras.papel.asiento_papel[0].papel) &&
  extras.papel.nomina_papel.aal2.length === 1 && /^Nómina de Gusto del 23-oct-2026/.test(extras.papel.nomina_papel.aal2[0].papel) && extras.papel.nomina_papel.aal1.length === 0,
  'el papel del asiento de la nómina: la vista sellada dice que no está, v_nomina_papel lo da con el código y nada sin él');
debe(extras.sin_dia.error.error.code === 'MX009' && /día de pago/.test(extras.sin_dia.error.error.message) && extras.sin_dia.ensayo.corridas.length === 1 && extras.sin_dia.ensayo.corridas[0].dia_pago === DIA_SIN &&
  Number(extras.sin_dia.ensayo.corridas[0].totales.bruto) === 100 && extras.sin_dia.importar.corridas[0].resultado === 'nueva' &&
  uno(`select count(*) from nomina_corridas where dia_pago = ${q(DIA_SIN)}::date`) === 0,
  'el archivo sin día de pago: MX009; con el día dicho se lee, e importarlo así entra (aquí, deshecho)');
{ const y = (extras.sin_dia.otra_vez.ensayo.corridas[0] || {}).ya_estaba || {};
  debe(extras.sin_dia.otra_vez.ensayo.entraria === 0 && y.mismas_cifras === true && y.otro_dia === true && y.mismo_archivo === true && y.dia_pago === DIA_SIN &&
    uno(`select count(*) from nomina_corridas where dia_pago in (${q(DIA_SIN)}::date, ${q(DIA_OTRO)}::date)`) === 0,
    'el mismo archivo sin fechas, otra vez y diciendo otro día (dos semanas después): ya está —sale del mismo archivo— y no entra nada');
  const i1 = extras.sin_dia.otra_vez.importar.corridas[0] || {}, i2 = extras.sin_dia.otra_vez.importar_porque.corridas[0] || {};
  debe(i1.resultado === 'ya_estaba' && i1.otro_dia === true && /sale del mismo archivo que aquella: es la misma\. Si de verdad es otra nómina, súbela como otra nómina diciendo por qué/.test(i1.texto) &&
    Number(extras.sin_dia.otra_vez.importar.nuevas) === 0 && i2.resultado === 'nueva' && Number(extras.sin_dia.otra_vez.importar_porque.nuevas) === 1,
    'importarlo así: ya estaba, con otro día, y la base dice cómo entra si de verdad es otra; con su porqué, entra'); }
const sinArchivos = JSON.stringify({ FILAS, c15, extras });
for (const t of ['000-00-0001', '000-00-0002', '000-00-0003', '000-00-0009', 'Calle Falsa', '"SSN"', 'Home address', 'ZZ Nota', '555-01', 'Home phone']) {
  if (sinArchivos.includes(t)) throw new Error(`«${t}» salió en lo que se mandó o en lo que contestó el banco: no puede ser`);
}
const salida = {
  _leeme: 'La base simulada de «Nómina» (c15) que usa pantalla.js: lo que contestó el banco. La genera pruebas/conta/f15-capturar.js; no se edita a mano. Datos inventados (ZZ y C15 PRUEBA); las columnas delicadas de los archivos son de mentira (000-00-000N no existe).',
  capturado: { hoy, plantilla: PLANTILLA, c15: crypto.createHash('sha1').update(fs.readFileSync(path.join(ROOT, 'docs/conta/c15-nomina.sql'))).digest('hex').slice(0, 12),
    semilla: crypto.createHash('sha1').update(fs.readFileSync(path.join(__dirname, 'f15-semilla.sql'))).digest('hex').slice(0, 12) },
  ids: { ...ID, rangos: RANGOS },
  textos: { ...T, cfg: CFG },
  archivos: Object.fromEntries(Object.entries(ARCHIVOS).map(([k, a]) => [k, { nombre: a.nombre, texto: a.texto, sha256: sha(a.texto) }])),
  filas: FILAS, c15, extras
};
fs.writeFileSync(SALIDA, JSON.stringify(salida) + '\n');
const kb = (fs.statSync(SALIDA).size / 1024).toFixed(0);
console.log(`listo: ${path.relative(ROOT, SALIDA)} (${kb} KB, ${Object.keys(FILAS).length} filas; ${c15.escenas.length} escenas y ${Object.keys(c15.errores).length} errores)`);
