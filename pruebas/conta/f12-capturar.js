/* f12-capturar.js — LA BASE SIMULADA de las páginas «Cédula de corte» (c13) y
   «Subs y 1099» (c14) de pruebas/conta/pantalla.js, SACADA DEL BANCO.

   No hay una mentira escrita a mano para estas dos capas: cada respuesta que
   la pantalla recibe en pantalla.js es la que dio el banco (Postgres 17 en
   127.0.0.1:5433) a la misma llamada, como el dueño (authenticated, aal2).
   Este script:
     1. arma <bd> (BORRA la que haya con ese nombre): un clon de la plantilla
        (de fábrica g10a: la cadena entera pegada como en producción) con
        06-produccion-facturas.sql, c13-cedula.sql, c14-subs.sql y
        f12-semilla.sql (un libro de octubre y noviembre en uso, inventado);
     2. lee todo lo que la pantalla lee (la ESCENA 0), y después hace, EN EL
        ORDEN DE LA PRUEBA, cada cosa que la pantalla escribe (un PASO), y tras
        cada paso vuelve a leerlo todo (la escena siguiente). c13 y c14 son dos
        cadenas aparte (no se leen una a la otra);
     3. prueba, sin dejar nada, los errores que la pantalla enseña (un TIN mal
        escrito, sin el código del teléfono, el equipo, un monto en cero…), y
        antes de cada paso que la base solo deja con «desde» o «corrige», lo que
        contesta a la misma orden sin eso (MX008 con su pista: «pide»); y una
        lectura APARTE de la cédula, en una transacción que se deshace (la forma
        de pago «efectivo» de c3 apuntada al 1093: el OJO de su origen);
     4. escribe pruebas/conta/pantalla-f12.json: cada fila una vez (por su
        huella), y de cada escena solo lo que cambió respecto de la anterior.
   pantalla.js lo carga: una lectura sale de la escena en que va su cadena; una
   escritura que coincide con el paso siguiente (por su función y sus llaves)
   pasa a la escena de ese paso y contesta lo que contestó el banco; los
   errores los elige la mentira con la misma regla que la base (texto corto,
   monto en cero, sin código…) y contesta el del banco.

   Los textos y los números son los del banco del día en que se capturó (lo
   que depende de «hoy» —los días que le quedan a un COI, la fecha de una
   explicación— es de ese día): la pantalla los enseña tal cual. Si c13 o c14
   cambian, se vuelve a correr y la prueba de la pantalla sigue con lo nuevo.

   Uso (solo el banco; nada de red):
     node pruebas/conta/f12-capturar.js <bd> [plantilla=g10a]
   Con --solo-montar arma la base (paso 1), escribe sus ids en una línea de
   JSON y para: así se compara la base simulada con un banco recién armado.
   Tarda unos 30 s. La base queda (con lo que escribieron los pasos); se borra
   a mano: runuser -u postgres -- psql -X -h /var/run/postgresql -p 5433 -c "drop database <bd>". */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { execFileSync } = require('child_process');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--')), SOLO_MONTAR = process.argv.includes('--solo-montar');
const BD = ARGS[0], PLANTILLA = ARGS[1] || 'g10a';
if (!BD || !/^[a-z][a-z0-9_]*$/.test(BD) || ['g10a', 'g9a', 'g8a', 'f9fix', 'p1fab', 'c9perf', PLANTILLA].includes(BD)) {
  console.error('uso: node pruebas/conta/f12-capturar.js <bd nueva> [plantilla=g10a]   (nunca una plantilla)'); process.exit(2);
}
const ROOT = path.resolve(__dirname, '..', '..');
const SALIDA = path.join(__dirname, 'pantalla-f12.json');
const ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT: '5433', PGPASSWORD: 'editor_sql' };
const DUENO = '00000000-0000-4000-a000-000000000001', EQUIPO = '00000000-0000-4000-a000-000000000002';

// ---------- el banco ----------
const su = sql => execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', '5433', '-v', 'ON_ERROR_STOP=1', '-c', sql], { stdio: ['ignore', 'pipe', 'pipe'] });
const suEn = (bd, sql) => execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', '5433', '-d', bd, '-v', 'ON_ERROR_STOP=1', '-c', sql], { stdio: ['ignore', 'pipe', 'pipe'] });
function pegar(archivo) {
  // como el SQL Editor: editor_sql, una transacción, para al primer error
  execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-f', archivo], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
}
function psql(sql) {
  return execFileSync('psql', ['-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-f', '-'], { env: ENV, input: sql, stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 1 << 28 }).toString();
}
const dolar = s => { let t = 'q'; while (s.includes(`$${t}$`)) t += 'x'; return `$${t}$${s}$${t}$`; };
// Una orden como la pantalla por PostgREST: quien (dueno | equipo), su nivel (aal2 | aal1), lo de antes en la misma
// transacción (subir un objeto a Storage) y la consulta, que devuelve un jsonb. Un error vuelve como {ERROR, message,
// detail, hint} y lo que hizo esa orden se deshace (el bloque con excepción es su subtransacción).
const AYUDA = `
create or replace function pg_temp.pedir(p_sql text, p_quien text, p_aal text, p_antes text) returns jsonb language plpgsql as $f$
declare v jsonb; uid text; c text; m text; d text; h text;
begin
  uid := case p_quien when 'dueno' then '${DUENO}' when 'equipo' then '${EQUIPO}' end;
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', p_aal)::text, true);
  perform set_config('request.jwt.claim.sub', uid, true);
  execute 'set local role authenticated';
  begin
    if p_antes is not null then execute p_antes; end if;
    execute p_sql into v;
  exception when others then
    get stacked diagnostics c = returned_sqlstate, m = message_text, d = pg_exception_detail, h = pg_exception_hint;
    v := jsonb_build_object('ERROR', c, 'message', m, 'detail', nullif(d, ''), 'hint', nullif(h, ''));
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return v;
end $f$;`;
// muchas órdenes en una sesión (una línea de JSON por orden); con commit lo que salió bien se queda. «previo»: lo que hace
// antes el SQL Editor (editor_sql), en la misma transacción (con rollback no queda)
function pedir(ordenes, fin = 'commit', previo = null) {
  const sql = ['begin;', AYUDA, ...(previo ? [previo] : []), ...ordenes.map(o => `select coalesce(pg_temp.pedir(${dolar(o.sql)}, '${o.quien || 'dueno'}', '${o.aal || 'aal2'}', ${o.antes ? dolar(o.antes) : 'null'})::text, 'null');`), fin + ';'].join('\n');
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
const filasDe = (consulta) => `coalesce((select jsonb_agg(to_jsonb(x)) from (${consulta}) x), '[]'::jsonb)`;

// ---------- 1. armar la base ----------
console.log(`armando ${BD} desde ${PLANTILLA}…`);
su(`drop database if exists ${BD}`);
su(`create database ${BD} template ${PLANTILLA} owner editor_sql`);
su(`grant create on database ${BD} to editor_sql`);
for (const f of ['pruebas/conta/06-produccion-facturas.sql', 'docs/conta/c13-cedula.sql', 'docs/conta/c14-subs.sql']) { pegar(path.join(ROOT, f)); console.log('  pegado', f); }
execFileSync('psql', ['-X', '-q', '-U', 'editor_sql', '-d', BD, '-f', path.join(__dirname, 'f12-semilla.sql')], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
// los nombres de la semilla de la plantilla que quedaron escritos en el libro (un trabajo externo y su asiento), cambiados por
// inventados con «ZZ»: solo en este clon, como superusuario (las guardas del libro no dejan cambiar un asiento, con razón)
suEn(BD, `set session_replication_role = replica;
update asientos set descripcion = replace(replace(descripcion, 'Luis — ayudante', 'ZZ Ayudante Tres'), 'Casa Pérez', 'ZZ Casa Uno') where descripcion ~ 'Luis|Pérez';
update asiento_lineas set memo = replace(memo, 'Luis — ayudante', 'ZZ Ayudante Tres') where memo ~ 'Luis';
update trabajos_externos set descripcion = replace(descripcion, 'Luis — ayudante', 'ZZ Ayudante Tres') where descripcion ~ 'Luis';
update externos_equipo set nombre = 'ZZ Ayudante Tres' where nombre ~ 'Luis';`);
console.log('  semilla puesta');

// ---------- los ids que la prueba necesita ----------
const uno = sql => JSON.parse(psql(`select coalesce(to_jsonb((${sql})), 'null')::text;`).trim());
const ID = {
  sub_uno: uno(`select id from proveedores where nombre = 'ZZ Sub Electrico Uno'`),
  sub_dos: uno(`select id from proveedores where nombre = 'ZZ Sub Zanjas Dos'`),
  prov_zzeli: uno(`select id from proveedores where nombre = 'ZZ Zzeli Trabajos'`),
  ficha_uno: uno(`select id from subs_fichas where nombre_legal = 'ZZ Sub Electrico Uno LLC'`),
  ficha_ayudante: uno(`select id from subs_fichas where nombre_legal = 'Zzeli Ayudante ZZ'`),
  asiento_zelle: uno(`select a.id from asientos a where a.descripcion = 'ZZ: Zelle payment to ZZ SUB ELECTRICO UNO'`),
  asiento_bolsillo: uno(`select a.id from asientos a where a.descripcion = 'ZZ: zanja extra, la pagó Edgar de su bolsillo'`),
  renglon_garantia: uno(`select id from cedula_manual where concepto = 'ZZ REAL: depósito en garantía del local'`),
  renglon_941: uno(`select id from cedula_manual where concepto = 'ZZ REAL: 941 por depositar'`),
  ayudante: EQUIPO
};
for (const [k, v] of Object.entries(ID)) if (!v) throw new Error('falta el id de ' + k);
if (SOLO_MONTAR) { console.log(JSON.stringify(ID)); process.exit(0); }

// ---------- 2. lo que la pantalla lee ----------
const FECHAS = ['2026-09-30', '2026-10-31', '2026-11-12'], ANIOS = [2026, 2027];
function lecturas13() {
  const o = [];
  for (const d of FECHAS) {
    o.push({ k: `fn_cedula_resumen|${d}`, sql: `select fn_cedula_resumen('${d}')` });
    o.push({ k: `fn_cedula|${d}`, sql: 'select ' + filasDe(`select * from fn_cedula('${d}') order by orden, cuenta`) });
    o.push({ k: `fn_cedula_partidas|${d}`, sql: 'select ' + filasDe(`select * from fn_cedula_partidas('${d}', null) order by cuenta, n`) });
  }
  o.push({ k: 'fn_cedula_resumen|', sql: `select fn_cedula_resumen(null)` });
  for (const p of ['2026-09-APERTURA', '2026-10', '2026-11', '']) {
    o.push({ k: `fn_cedula_control|${p}`, sql: 'select ' + filasDe(`select * from fn_cedula_control(${p ? `'${p}'` : 'null'}) order by orden`) });
  }
  for (const p of ['2026-09-APERTURA', '2026-10', '2026-11']) o.push({ k: `fn_cedula_cierre|${p}`, sql: 'select ' + filasDe(`select * from fn_cedula_cierre('${p}')`) });
  o.push({ k: 'fn_cedula_cuentas|', sql: 'select ' + filasDe(`select * from fn_cedula_cuentas() order by cuenta`) });
  o.push({ k: 'fn_cedula_config|', sql: `select fn_cedula_config(null)` });
  o.push({ k: 'fn_cedula_capas|', sql: `select fn_cedula_capas()` });
  o.push({ k: 'fn_cedula_qb_periodos|', sql: 'select ' + filasDe(`select * from fn_cedula_qb_periodos() order by periodo desc`) });
  for (const p of ['2026-10']) o.push({ k: `fn_cedula_qb|${p}`, sql: 'select ' + filasDe(`select * from fn_cedula_qb('${p}') order by orden, cuenta`) });
  o.push({ k: 'v_cedula_manual', sql: 'select ' + filasDe(`select * from v_cedula_manual order by cuenta, desde, creado_el`) });
  o.push({ k: 'v_cedula_explicaciones', sql: 'select ' + filasDe(`select * from v_cedula_explicaciones order by explicado_el, cuenta`) });
  o.push({ k: 'cedula_config', sql: 'select ' + filasDe(`select * from cedula_config`) });
  return o;
}
function lecturas14() {
  const o = [];
  o.push({ k: 'fn_subs_anios|', sql: 'select ' + filasDe(`select * from fn_subs_anios() order by anio`) });
  for (const a of ANIOS) {
    o.push({ k: `fn_subs_1099|${a}`, sql: 'select ' + filasDe(`select * from fn_subs_1099(${a}) order by clave`) });
    o.push({ k: `fn_subs_pagos|${a}`, sql: 'select ' + filasDe(`select * from fn_subs_pagos(${a}) order by fecha, numero, orden`) });
    o.push({ k: `fn_subs_control|${a}`, sql: 'select ' + filasDe(`select * from fn_subs_control(${a}) order by orden`) });
    o.push({ k: `fn_subs_umbral|${a}`, sql: `select to_jsonb(fn_subs_umbral(${a}))` });
    o.push({ k: `fn_subs_antes|${a}`, sql: 'select ' + filasDe(`select * from fn_subs_antes(${a}) order by clave`) });
  }
  o.push({ k: 'fn_subs_control|', sql: 'select ' + filasDe(`select * from fn_subs_control(null) order by orden`) });
  for (const p of ['2026-10', '2026-11']) o.push({ k: `fn_subs_cierre|${p}`, sql: 'select ' + filasDe(`select * from fn_subs_cierre('${p}') order by orden`) });
  o.push({ k: 'v_subs_fichas', sql: 'select ' + filasDe(`select * from v_subs_fichas order by nombre, ficha_id`) });
  o.push({ k: 'v_subs_archivos', sql: 'select ' + filasDe(`select * from v_subs_archivos order by registrado_el, archivo_id`) });
  o.push({ k: 'v_subs_coi', sql: 'select ' + filasDe(`select * from v_subs_coi order by nombre, clave`) });
  o.push({ k: 'subs_config', sql: 'select ' + filasDe(`select * from subs_config`) });
  o.push({ k: 'subs_umbrales', sql: 'select ' + filasDe(`select * from subs_umbrales order by anio`) });
  o.push({ k: 'subs_tramos', sql: 'select ' + filasDe(`select * from subs_tramos order by hasta, anotado_el`) });
  o.push({ k: 'subs_exportaciones', sql: 'select ' + filasDe(`select id, anio, filas, total, umbral, opciones, pendientes, generado_el, generado_por from subs_exportaciones order by generado_el`) });
  o.push({ k: 'proveedores', sql: 'select ' + filasDe(`select id, nombre, activo from proveedores order by nombre`) });
  return o;
}

// ---------- 3. el almacén: cada fila una vez, por su huella ----------
const FILAS = {};
const huella = v => crypto.createHash('sha1').update(JSON.stringify(v)).digest('hex').slice(0, 12);
function guardar(v) {
  if (!Array.isArray(v)) return { valor: v };
  return { filas: v.map(f => { const h = huella(f); FILAS[h] = f; return h; }) };
}
// una escena: las lecturas que cambiaron respecto de lo acumulado (la primera, todas)
function escena(lect, acumulado, paso) {
  const r = pedir(lect.map(x => ({ sql: x.sql })));
  const cambia = {};
  lect.forEach((x, i) => {
    if (r[i] && r[i].ERROR) throw new Error(`la lectura ${x.k} dio ${r[i].ERROR}: ${r[i].message}`);
    const g = guardar(r[i]), s = JSON.stringify(g);
    if (acumulado[x.k] !== s) { cambia[x.k] = g; acumulado[x.k] = s; }
  });
  return { paso: paso || null, lecturas: cambia };
}

// ---------- 4. los pasos (lo que la pantalla escribe, en el orden de la prueba) ----------
const q = v => v == null ? 'null' : `'${String(v).replace(/'/g, "''")}'`;
const jb = o => `${q(JSON.stringify(o))}::jsonb`;
// el «archivo» que la prueba sube: los mismos bytes en el banco (su tamaño) y en pantalla.js (su sha256)
const BYTES = { w9: 2048, coi: 3072 };
const sha = n => crypto.createHash('sha256').update(Buffer.alloc(n, 0x25)).digest('hex');
const subir = (ruta, n) => `insert into storage.objects (bucket_id, name, owner, metadata) values ('subs', ${q(ruta)}, auth.uid(), jsonb_build_object('size', ${n}))`;

function cadena(nombre, lect, pasos, errores) {
  const acumulado = {}, escenas = [escena(lect(), acumulado)], P = {}, E = {};
  const correrErrores = antes => {
    for (const e of errores.filter(x => x.antes === antes)) {
      const a = typeof e.args === 'function' ? e.args() : e.args;
      // en su propia sesión, que se deshace entera (rollback): un error que no salga como error no deja nada
      const [r] = pedir([{ sql: `select to_jsonb(${e.fn}(${a.sql}))`, quien: e.quien, aal: e.aal, antes: a.subir || null }], 'rollback');
      if (!r || !r.ERROR) throw new Error(`${nombre}: «${e.nombre}» no dio error: ${JSON.stringify(r).slice(0, 200)}`);
      E[e.nombre] = { fn: e.fn, args: a.json, ...comoPostgrest(r) };
    }
  };
  correrErrores(null);
  for (const p of pasos) {
    const a = typeof p.args === 'function' ? p.args() : p.args;
    // el paso que la base solo deja con «desde» o «corrige»: antes, la misma orden sin eso, y lo que pide (MX008 con su pista)
    if (p.pide) {
      const b = p.pide.args();
      const [r] = pedir([{ sql: `select to_jsonb(${p.fn}(${b.sql}))` }], 'rollback');
      if (!r || r.ERROR !== 'MX008' || !r.hint) throw new Error(`${nombre}: «${p.pide.nombre}» no pidió nada: ${JSON.stringify(r).slice(0, 200)}`);
      E[p.pide.nombre] = { fn: p.fn, args: b.json, ...comoPostgrest(r) };
    }
    const [r] = pedir([{ sql: `select to_jsonb(${p.fn}(${a.sql}))`, antes: a.subir || null }]);
    if (r && r.ERROR) throw new Error(`${nombre}: el paso «${p.nombre}» dio ${r.ERROR}: ${r.message}`);
    if (p.despues) p.despues(r);
    P[p.nombre] = { fn: p.fn, args: a.json, igual: p.igual || [], respuesta: r, ...(p.pide ? { pide: p.pide.nombre } : {}) };
    escenas.push(escena(lect(), acumulado, p.nombre));
    console.log(`  ${nombre} · ${p.nombre}: ${Object.keys(escenas[escenas.length - 1].lecturas).length} lectura(s) cambiaron`);
    correrErrores(p.nombre);
  }
  return { escenas, pasos: P, orden: pasos.map(p => p.nombre), errores: E };
}

// --- c13: la cédula ---
const T13 = {
  explicar_2010: 'ZZ: los $60 son la factura del gas que llegó sin proveedor; se arregla en noviembre',
  explicar_2050: 'ZZ: los $340 son la provisión de la auditoría de seguros y la de octubre que entró después',
  retirar_1110: 'ZZ: ya llegó la factura de QuickBooks',
  anular: 'ZZ: estaba duplicado'
};
const R1600 = { cuenta: '1600', concepto: 'ZZ: depósito de la luz', monto: '150.00', desde: '2026-10-20', documento: 'ZZ recibo 4471', nota: 'Se devuelve al cerrar el contrato' };
let renglonNuevo = null, renglonCorregido = null;
const pasos13 = [
  { nombre: 'explicar_2010', fn: 'fn_cedula_explicar', igual: ['p_cuenta', 'p_fecha'], args: { sql: `'2010', '2026-10-31', ${q(T13.explicar_2010)}`, json: { p_cuenta: '2010', p_fecha: '2026-10-31', p_texto: T13.explicar_2010 } } },
  { nombre: 'renglon_1600', fn: 'fn_cedula_renglon', igual: ['p.cuenta', 'p.concepto'], args: { sql: jb(R1600), json: { p: R1600 } }, despues: r => { renglonNuevo = r.id; } },
  { nombre: 'corregir_1600', fn: 'fn_cedula_renglon', igual: ['p.id'], args: () => { const p = { id: renglonNuevo, concepto: R1600.concepto, monto: '175.00', desde: R1600.desde, hasta: '', documento: R1600.documento, nota: R1600.nota }; return { sql: jb(p), json: { p } }; }, despues: r => { renglonCorregido = r.id; } },
  { nombre: 'anular_1600', fn: 'fn_cedula_renglon_anular', igual: ['p_id'], args: () => ({ sql: `${q(renglonCorregido)}::uuid, ${q(T13.anular)}`, json: { p_id: renglonCorregido, p_motivo: T13.anular } }) },
  { nombre: 'explicar_2050', fn: 'fn_cedula_explicar', igual: ['p_cuenta', 'p_fecha'], args: { sql: `'2050', '2026-10-31', ${q(T13.explicar_2050)}`, json: { p_cuenta: '2050', p_fecha: '2026-10-31', p_texto: T13.explicar_2050 } } },
  { nombre: 'retirar_1110', fn: 'fn_cedula_explicacion_retirar', igual: ['p_cuenta', 'p_fecha'], args: { sql: `'1110', '2026-10-31', ${q(T13.retirar_1110)}`, json: { p_cuenta: '1110', p_fecha: '2026-10-31', p_motivo: T13.retirar_1110 } } },
  { nombre: 'config', fn: 'fn_cedula_config', igual: [], args: { sql: jb({ avisar_desde: '2026-11', patrimonio: 'mayor' }), json: { p: { avisar_desde: '2026-11', patrimonio: 'mayor' } } } }
];
const e13 = (nombre, fn, sql, json, extra = {}) => ({ nombre, fn, args: { sql, json }, antes: null, ...extra });
const errores13 = [
  e13('explicar_corto', 'fn_cedula_explicar', `'2010', '2026-10-31', 'ZZ corto'`, { p_cuenta: '2010', p_fecha: '2026-10-31', p_texto: 'ZZ corto' }),
  e13('explicar_cuadra', 'fn_cedula_explicar', `'1520', '2026-10-31', 'ZZ: esto cuadra y no hay nada que explicar'`, { p_cuenta: '1520', p_fecha: '2026-10-31', p_texto: 'ZZ: esto cuadra y no hay nada que explicar' }),
  e13('explicar_futuro', 'fn_cedula_explicar', `'2010', '2026-12-31', 'ZZ: una fecha que todavía no llega'`, { p_cuenta: '2010', p_fecha: '2026-12-31', p_texto: 'ZZ: una fecha que todavía no llega' }),
  e13('retirar_nada', 'fn_cedula_explicacion_retirar', `'1520', '2026-10-31', 'ZZ: no hay nada'`, { p_cuenta: '1520', p_fecha: '2026-10-31', p_motivo: 'ZZ: no hay nada' }),
  e13('renglon_cero', 'fn_cedula_renglon', jb({ ...R1600, monto: '0' }), { p: { ...R1600, monto: '0' } }),
  e13('renglon_monto_mal', 'fn_cedula_renglon', jb({ ...R1600, monto: '15o' }), { p: { ...R1600, monto: '15o' } }),
  e13('renglon_tres_decimales', 'fn_cedula_renglon', jb({ ...R1600, monto: '150.001' }), { p: { ...R1600, monto: '150.001' } }),
  e13('renglon_sin_desde', 'fn_cedula_renglon', jb({ ...R1600, desde: '' }), { p: { ...R1600, desde: '' } }),
  e13('renglon_sin_concepto', 'fn_cedula_renglon', jb({ ...R1600, concepto: '' }), { p: { ...R1600, concepto: '' } }),
  e13('equipo_resumen', 'fn_cedula_resumen', `'2026-10-31'`, { p_fecha: '2026-10-31' }, { quien: 'equipo' }),
  e13('equipo_explicar', 'fn_cedula_explicar', `'2010', '2026-10-31', ${q(T13.explicar_2010)}`, { p_cuenta: '2010', p_fecha: '2026-10-31', p_texto: T13.explicar_2010 }, { quien: 'equipo' }),
  e13('anular_otra_vez', 'fn_cedula_renglon_anular', null, null, { antes: 'anular_1600', args: () => ({ sql: `${q(renglonCorregido)}::uuid, 'ZZ otra vez'`, json: { p_id: renglonCorregido, p_motivo: 'ZZ otra vez' } }) })
];

// --- c14: los subs ---
const T14 = {
  marcar: 'ZZ: el Zelle del 16 de octubre era para el sub uno',
  umbral: 'ZZ: lo confirmó el CPA el 12 de noviembre',
  ayudante: 'ZZ: el CPA dijo que es empleado (va por Gusto desde enero)',
  retirar: 'ZZ: era el de otro sub',
  desmarcar: 'ZZ: me equivoqué de ficha',
  pagado: 'ZZ: el CPA dice que cuenta: lo pagó la empresa, que se lo devolvió a Edgar',
  uno_no: 'ZZ: desde noviembre factura por su corporación (W-9 nuevo)',
  tramo: 'ZZ: el W-9 nuevo es de diciembre, no de noviembre'
};
let fichaDos = null, coiDos = null, tramoUno = null;
const fichaDosP = () => ({ nombre_legal: 'ZZ Sub Zanjas Dos', nombre_comercial: 'ZZ Zanjas', tipo_entidad: 'sole_proprietor', reporta: 'si', reporta_nota: null,
  direccion: '5 ZZ Rd', direccion2: null, ciudad: 'Ocala', estado: 'FL', zip: '34471', wc_exento: false, notas: null, activa: true, tercero: { tipo: 'proveedor', id: ID.sub_dos } });
const ayudanteP = () => ({ id: ID.ficha_ayudante, nombre_legal: 'Zzeli Ayudante ZZ', nombre_comercial: null, tipo_entidad: 'individual', reporta: 'no', reporta_nota: T14.ayudante,
  direccion: '7 ZZ Ln', direccion2: null, ciudad: 'Ocala', estado: 'FL', zip: '34472', wc_exento: false, notas: null, activa: true });
// (la ficha del sub uno como la manda la pantalla, con «no» desde el 1-nov: lo de antes queda en un tramo)
const unoNoP = () => ({ id: ID.ficha_uno, nombre_legal: 'ZZ Sub Electrico Uno LLC', nombre_comercial: 'ZZ Rayo', tipo_entidad: 'llc_un_socio', reporta: 'no', reporta_nota: T14.uno_no,
  direccion: '1 Calle Falsa', direccion2: 'Suite 2', ciudad: 'Ocala', estado: 'FL', zip: '34470', wc_exento: false, notas: null, activa: true });
const archivoP = (ficha, clase, extra) => ({ clase, ruta: `${ficha}/${clase}/${clase}-2026-11-12_090000.pdf`, sha256: sha(BYTES[clase]), bytes: BYTES[clase], ...extra });
const CFG14 = { umbral_1099: '2000.00', entidades_no_reporta: ['c_corp', 's_corp'], cuentas_por_pagar: ['2010', '2020'], cuentas_no_pago: ['1020'], cuentas_no_servicio: [],
  coi_aviso_dias: 45, coi_ventana_dias: 90, coi_exento_basta: false, fecha_pago: 'contable' };
// lo que la base solo deja con «desde» o «corrige»: la misma orden sin eso, que contesta MX008 con lo que pide
const sinPide = o => { const x = { ...o }; delete x.desde; delete x.corrige; return x; };
const pasos14 = [
  { nombre: 'ficha_dos', fn: 'fn_subs_ficha', igual: ['p.tercero.id'], args: () => ({ sql: jb(fichaDosP()), json: { p: fichaDosP() } }), despues: r => { fichaDos = r.ficha_id; } },
  { nombre: 'tin_dos', fn: 'fn_subs_tin_guardar', igual: ['p_ficha'], args: () => ({ sql: `${q(fichaDos)}::uuid, ${jb({ tin: '000-00-0003' })}`, json: { p_ficha: fichaDos, p: { tin: '000-00-0003' } } }) },
  { nombre: 'w9_dos', fn: 'fn_subs_archivo', igual: ['p_ficha', 'p.clase'], args: () => { const p = archivoP(fichaDos, 'w9', { fecha: '2026-11-12' }); return { sql: `${q(fichaDos)}::uuid, ${jb(p)}`, json: { p_ficha: fichaDos, p }, subir: subir(p.ruta, p.bytes) }; } },
  { nombre: 'coi_dos', fn: 'fn_subs_archivo', igual: ['p_ficha', 'p.clase'], args: () => { const p = archivoP(fichaDos, 'coi', { vence: '2026-12-02' }); return { sql: `${q(fichaDos)}::uuid, ${jb(p)}`, json: { p_ficha: fichaDos, p }, subir: subir(p.ruta, p.bytes) }; }, despues: r => { coiDos = r.archivo.id; } },
  { nombre: 'marcar_zelle', fn: 'fn_subs_marcar', igual: ['p_asiento', 'p_orden'], args: () => ({ sql: `${q(ID.asiento_zelle)}::uuid, 1, ${jb({ ficha: ID.ficha_uno, nota: T14.marcar })}`, json: { p_asiento: ID.asiento_zelle, p_orden: 1, p: { ficha: ID.ficha_uno, nota: T14.marcar } } }) },
  // (el ayudante tiene pagos con «por decidir»: la base pide desde cuándo; el CPA dijo que siempre fue empleado: «corrige»)
  { nombre: 'ficha_ayudante', fn: 'fn_subs_ficha', igual: ['p.id'], args: () => { const p = { ...ayudanteP(), corrige: true }; return { sql: jb(p), json: { p } }; },
    pide: { nombre: 'ficha_ayudante_pide', args: () => { const p = ayudanteP(); return { sql: jb(p), json: { p } }; } } },
  { nombre: 'umbral_2026', fn: 'fn_subs_umbral_confirmar', igual: ['p_anio'], args: { sql: `2026, '2000', ${q(T14.umbral)}`, json: { p_anio: 2026, p_umbral: '2000', p_nota: T14.umbral } } },
  { nombre: 'exportar_2026', fn: 'fn_subs_1099_export', igual: ['p_anio'], args: { sql: `2026, ${jb({ bajo_umbral: false })}`, json: { p_anio: 2026, p_opciones: { bajo_umbral: false } } } },
  { nombre: 'w9_uno', fn: 'fn_subs_archivo', igual: ['p_ficha', 'p.clase'], args: () => { const p = archivoP(ID.ficha_uno, 'w9', { fecha: '2026-11-12' }); return { sql: `${q(ID.ficha_uno)}::uuid, ${jb(p)}`, json: { p_ficha: ID.ficha_uno, p }, subir: subir(p.ruta, p.bytes) }; } },
  { nombre: 'config', fn: 'fn_subs_config', igual: [], args: { sql: jb(CFG14), json: { p: CFG14 } } },
  { nombre: 'retirar_coi_dos', fn: 'fn_subs_archivo_retirar', igual: ['p_archivo'], args: () => ({ sql: `${q(coiDos)}::uuid, ${q(T14.retirar)}`, json: { p_archivo: coiDos, p_motivo: T14.retirar } }) },
  { nombre: 'tercero_zzeli', fn: 'fn_subs_tercero', igual: ['p_ficha', 'p_id', 'p_quitar'], args: () => ({ sql: `${q(ID.ficha_ayudante)}::uuid, 'proveedor', ${q(ID.prov_zzeli)}::uuid, false`, json: { p_ficha: ID.ficha_ayudante, p_tipo: 'proveedor', p_id: ID.prov_zzeli, p_quitar: false } }) },
  { nombre: 'tercero_soltar', fn: 'fn_subs_tercero', igual: ['p_ficha', 'p_id', 'p_quitar'], args: () => ({ sql: `${q(ID.ficha_ayudante)}::uuid, 'proveedor', ${q(ID.prov_zzeli)}::uuid, true`, json: { p_ficha: ID.ficha_ayudante, p_tipo: 'proveedor', p_id: ID.prov_zzeli, p_quitar: true } }) },
  // (cambiar el TIN por otro en una ficha con pagos: la base pide confirmar que era un error de dedo)
  { nombre: 'tin_corrige', fn: 'fn_subs_tin_guardar', igual: ['p_ficha'], args: () => ({ sql: `${q(fichaDos)}::uuid, ${jb({ tin: '000-00-0004', corrige: true })}`, json: { p_ficha: fichaDos, p: { tin: '000-00-0004', corrige: true } } }),
    pide: { nombre: 'tin_corrige_pide', args: () => ({ sql: `${q(fichaDos)}::uuid, ${jb({ tin: '000-00-0004' })}`, json: { p_ficha: fichaDos, p: { tin: '000-00-0004' } } }) } },
  { nombre: 'tin_quitar', fn: 'fn_subs_tin_guardar', igual: ['p_ficha', 'p.quitar'], args: () => ({ sql: `${q(fichaDos)}::uuid, ${jb({ quitar: true })}`, json: { p_ficha: fichaDos, p: { quitar: true } } }) },
  { nombre: 'desmarcar_zelle', fn: 'fn_subs_marcar', igual: ['p_asiento', 'p_orden', 'p.quitar'], args: () => ({ sql: `${q(ID.asiento_zelle)}::uuid, 1, ${jb({ quitar: true, nota: T14.desmarcar })}`, json: { p_asiento: ID.asiento_zelle, p_orden: 1, p: { quitar: true, nota: T14.desmarcar } } }) },
  // (lo que Edgar le pagó al sub dos de su bolsillo: «pagado», lo pagó la empresa por otro camino)
  { nombre: 'marcar_pagado', fn: 'fn_subs_marcar', igual: ['p_asiento', 'p_orden', 'p.trato'], args: () => ({ sql: `${q(ID.asiento_bolsillo)}::uuid, 1, ${jb({ nota: T14.pagado, trato: 'pagado' })}`, json: { p_asiento: ID.asiento_bolsillo, p_orden: 1, p: { nota: T14.pagado, trato: 'pagado' } } }) },
  // (el sub uno deja de reportarse desde el 1-nov: la base pide desde cuándo; lo de antes queda en un tramo; después se retira)
  { nombre: 'tramo_uno', fn: 'fn_subs_ficha', igual: ['p.id'], args: () => { const p = { ...unoNoP(), desde: '2026-11-01' }; return { sql: jb(p), json: { p } }; },
    pide: { nombre: 'tramo_uno_pide', args: () => { const p = unoNoP(); return { sql: jb(p), json: { p } }; } },
    despues: () => { tramoUno = uno(`select id from subs_tramos where ficha_id = ${q(ID.ficha_uno)}::uuid and retirado_el is null`); } },
  { nombre: 'tramo_retirar', fn: 'fn_subs_tramo_retirar', igual: ['p_tramo'], args: () => ({ sql: `${q(tramoUno)}::uuid, ${q(T14.tramo)}`, json: { p_tramo: tramoUno, p_motivo: T14.tramo } }) }
];
const e14 = (nombre, fn, args, extra = {}) => ({ nombre, fn, args, antes: null, ...extra });
const errores14 = [
  e14('ficha_tipo_mal', 'fn_subs_ficha', () => { const p = { ...ayudanteP(), tipo_entidad: 'sa_de_cv' }; return { sql: jb(p), json: { p } }; }),
  e14('ficha_zip_mal', 'fn_subs_ficha', () => { const p = { ...ayudanteP(), zip: '3447' }; return { sql: jb(p), json: { p } }; }),
  e14('ficha_estado_mal', 'fn_subs_ficha', () => { const p = { ...ayudanteP(), estado: 'Florida' }; return { sql: jb(p), json: { p } }; }),
  e14('equipo_ficha', 'fn_subs_ficha', () => { const p = ayudanteP(); return { sql: jb(p), json: { p } }; }, { quien: 'equipo' }),
  e14('tin_mal', 'fn_subs_tin_guardar', () => ({ sql: `${q(fichaDos)}::uuid, ${jb({ tin: '12-345' })}`, json: { p_ficha: fichaDos, p: { tin: '12-345' } } }), { antes: 'ficha_dos' }),
  e14('tin_sin_codigo', 'fn_subs_tin_guardar', () => ({ sql: `${q(fichaDos)}::uuid, ${jb({ tin: '000-00-0003' })}`, json: { p_ficha: fichaDos, p: { tin: '000-00-0003' } } }), { antes: 'ficha_dos', aal: 'aal1' }),
  e14('archivo_no_esta', 'fn_subs_archivo', () => { const p = archivoP(fichaDos, 'w9', { fecha: '2026-11-12' }); return { sql: `${q(fichaDos)}::uuid, ${jb(p)}`, json: { p_ficha: fichaDos, p } }; }, { antes: 'tin_dos' }),
  e14('coi_sin_vence', 'fn_subs_archivo', () => { const p = archivoP(fichaDos, 'coi', {}); return { sql: `${q(fichaDos)}::uuid, ${jb(p)}`, json: { p_ficha: fichaDos, p }, subir: subir(p.ruta, p.bytes) }; }, { antes: 'w9_dos' }),
  e14('marcar_sin_nota', 'fn_subs_marcar', () => ({ sql: `${q(ID.asiento_zelle)}::uuid, 1, ${jb({ ficha: ID.ficha_uno })}`, json: { p_asiento: ID.asiento_zelle, p_orden: 1, p: { ficha: ID.ficha_uno } } }), { antes: 'coi_dos' }),
  e14('umbral_mal', 'fn_subs_umbral_confirmar', { sql: `2026, '-5', ${q(T14.umbral)}`, json: { p_anio: 2026, p_umbral: '-5', p_nota: T14.umbral } }, { antes: 'ficha_ayudante' }),
  e14('umbral_sin_nota', 'fn_subs_umbral_confirmar', { sql: `2026, '2000', ''`, json: { p_anio: 2026, p_umbral: '2000', p_nota: '' } }, { antes: 'ficha_ayudante' }),
  e14('exportar_sin_codigo', 'fn_subs_1099_export', { sql: `2026, ${jb({ bajo_umbral: false })}`, json: { p_anio: 2026, p_opciones: { bajo_umbral: false } } }, { antes: 'umbral_2026', aal: 'aal1' }),
  e14('config_dias_mal', 'fn_subs_config', { sql: jb({ ...CFG14, coi_aviso_dias: 400 }), json: { p: { ...CFG14, coi_aviso_dias: 400 } } }, { antes: 'exportar_2026' }),
  e14('retirar_otra_vez', 'fn_subs_archivo_retirar', () => ({ sql: `${q(coiDos)}::uuid, 'ZZ otra vez'`, json: { p_archivo: coiDos, p_motivo: 'ZZ otra vez' } }), { antes: 'retirar_coi_dos' })
];

// ---------- 5. correr y escribir ----------
const hoy = JSON.parse(psql(`select to_jsonb(fn_fecha_miami(now()))::text;`).trim());
console.log('c13…');
const c13 = cadena('c13', lecturas13, pasos13, errores13);
// (APARTE, sin dejar nada: la forma de pago «efectivo» de c3 apuntada a un banco que se concilia —el 1093—; la cédula sigue
// tratándolo como un banco y su «origen» lo avisa con un OJO. Se lee en una transacción que se deshace, al final de la cadena)
{
  const [res, filas] = pedir([{ sql: `select fn_cedula_resumen('2026-10-31')` }, { sql: 'select ' + filasDe(`select * from fn_cedula('2026-10-31') order by orden, cuenta`) }], 'rollback',
    `update mapeo_metodo_pago set cuenta = '1093', confirmado_el = now() where forma = 'efectivo';`);
  if (!Array.isArray(filas) || !filas.some(f => f.cuenta === '1093' && /OJO/.test(f.origen || ''))) throw new Error('c13: con el efectivo en el 1093, su origen no trae el OJO');
  c13.aparte = { efectivo_banco: { 'fn_cedula_resumen|2026-10-31': guardar(res), 'fn_cedula|2026-10-31': guardar(filas) } };
}
console.log('c14…');
const c14 = cadena('c14', lecturas14, pasos14, errores14);
// ningún TIN entero fuera de la hoja exportada (la respuesta de exportar lo lleva: es lo que la pantalla baja como archivo)
const sinHoja = JSON.stringify({ FILAS, c13, c14: { ...c14, pasos: Object.fromEntries(Object.entries(c14.pasos).filter(([k]) => k !== 'exportar_2026')) } });
for (const t of ['000-00-0003', '00-0000071', '000000003', '000000071', '000-00-0004', '000000004']) {
  const sinArgs = sinHoja.replace(/"tin":"000-00-000[34]"/g, '');
  if (sinArgs.includes(t)) throw new Error(`el TIN ${t} salió en una lectura: no puede ser`);
}
const salida = {
  _leeme: 'La base simulada de «Cédula de corte» (c13) y «Subs y 1099» (c14) que usa pantalla.js: lo que contestó el banco. La genera pruebas/conta/f12-capturar.js; no se edita a mano. Datos inventados (ZZ).',
  capturado: { hoy, plantilla: PLANTILLA, c13: crypto.createHash('sha1').update(fs.readFileSync(path.join(ROOT, 'docs/conta/c13-cedula.sql'))).digest('hex').slice(0, 12), c14: crypto.createHash('sha1').update(fs.readFileSync(path.join(ROOT, 'docs/conta/c14-subs.sql'))).digest('hex').slice(0, 12) },
  ids: { ...ID, ficha_dos: fichaDos, coi_dos: coiDos, tramo_uno: tramoUno, renglon_nuevo: renglonNuevo, renglon_corregido: renglonCorregido },
  textos: { ...T13, ...Object.fromEntries(Object.entries(T14).map(([k, v]) => ['subs_' + k, v])), renglon: R1600, bytes: BYTES, sha: { w9: sha(BYTES.w9), coi: sha(BYTES.coi) } },
  filas: FILAS, c13, c14
};
fs.writeFileSync(SALIDA, JSON.stringify(salida) + '\n');
const kb = (fs.statSync(SALIDA).size / 1024).toFixed(0);
console.log(`listo: ${path.relative(ROOT, SALIDA)} (${kb} KB, ${Object.keys(FILAS).length} filas; c13 ${c13.escenas.length} escenas y ${Object.keys(c13.errores).length} errores; c14 ${c14.escenas.length} escenas y ${Object.keys(c14.errores).length} errores)`);
