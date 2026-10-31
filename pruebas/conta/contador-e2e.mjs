/* contador-e2e.mjs — la función de borde `contador` (c8, fase 7) de punta a
   punta, sin internet ni un token gastado: un Anthropic simulado
   (contador-simulado.mjs), la función contra el banco de pruebas (c1..c7 +
   s1 + p1 + c8-contador.sql) y las comprobaciones de lo que pasa en la base
   y de lo que llega a «Anthropic»:
     · quién puede llamar (dueño en aal2; sin aal2, el equipo, sin sesión, una
       sesión que no existe), la salud sin sesión, CORS, el banco de pruebas
       fuera del banco;
     · LA RÁFAGA: las reglas de Edgar contestan antes que la IA (gratis); la
       IA recibe UNA petición por movimiento, los más viejos primero, la
       primera sola (crea el caché del prefijo) y las demás de tres en tres
       (leen el caché); cada petición con la forma del contrato (opus 5.5,
       effort low, json_schema cerrado, cache_control, sin thinking, sin
       tool_choice, sin fallbacks), el prefijo determinista y sin fechas ni
       ids, el movimiento sin correos, teléfonos ni números de cuenta; las
       propuestas pendientes con su entrada congelada y la salida cruda; una
       negativa (refusal), un corte (max_tokens), un JSON roto y una cuenta
       inventada no guardan nada y se cuentan; 529/429/5xx reintentan UNA vez
       tras 2 s; el lote con su uso y sus centavos, y el gasto del mes sube;
     · EL TOPE (el del contador, el de la app, apagado): bloqueado sin llamar;
     · LO QUE EDGAR HACE: aprobar («Así es») → el asiento vivo de c6 en nombre
       del dueño y la regla aprendida, y el siguiente del mismo comercio sale
       por regla sin IA; la obra que se pide (MX008 sin ella); clasificar
       («Según yo») → editada, o una de Edgar sin propuesta; rechazar («No es
       eso») → y una regla rechazada no se repite; las reglas (alta con su
       cuenta del banco y sus partes, baja con sus propuestas caducadas);
       caducar una aprobada cuyo asiento se reversó;
     · la llave que no vale, un modelo que Anthropic no conoce, sin llave, la
       base caída; dos ráfagas a la vez (una entra y la otra se frena en la
       base: ningún cargo se paga dos veces); el reloj de la ráfaga (una
       llamada en vuelo se corta al llegar el plazo, lo que no entró espera);
       una ráfaga que se cortó sin cerrar (la alarma 72 lo dice y la base la
       da por perdida al abrir la siguiente);
     · y el cierre: v_contador_control en verde (y sus alarmas, en rojo cuando
       toca), fn_verificar_cadena, fn_banco_control, fn_puentes_verificar y
       fn_estados_control en verde (salvo la apertura de fábrica), ninguna
       fn_contador_* en la API ni SECURITY DEFINER, y la llave de prueba en
       ninguna respuesta, salida, petición ni tabla;
     · LA OBRA (7b, E2E-110 a E2E-128): las pistas de la obra que calcula la
       base (fn_contador_pistas_obra: las horas de la cuadrilla, los tickets
       del mismo comercio, lo que Edgar eligió, la lista de materiales)
       viajan a la IA en cada petición con la forma del contrato y sin nada
       personal (ningún usuario_id, nombre del equipo, nota de las horas ni
       ruta de foto); la IA propone la obra (el simulador copia la
       candidata) y la base la deja en la línea, con su confianza y su
       motivo en la bandeja y con_obra en la respuesta; una obra que no
       existe se descarta con su nota; la IA que no se atreve deja pide_obra
       y las pistas a la vista; Edgar aprueba sin elegir (entra la obra
       propuesta) o con otra (editada, entra la suya); una regla que pide
       obra lleva la candidata; la regla aprendida nunca guarda la obra; el
       cuadre 64; y (E2E-128, lo que destapó la verificación del 31-oct) la
       obra que se cierra DESPUÉS de proponerla no entra por un toque: el 64
       la nombra y «Así es» sin elegir, con esa misma obra y «Según yo» con
       ella en la línea contestan 409 MX008 «ya no está activa» con la pista
       «elige la obra». LAS PISTAS LAS SIEMBRA LA PRUEBA (horas a nombre del
       equipo, un ticket «por leer» y una fila de materiales, en obras y
       fechas escogidas) para que lo esperado no dependa del día en que se
       corre: las horas y los tickets de la semilla tienen fecha fija, y
       cada candidata se escoge con margen sobre lo que la semilla pueda
       sumar (las cuentas, junto a cada siembra). Las comprobaciones de la
       7b llevan número desde la 110 (las de antes no se renumeran) y van
       donde pasa lo que miden: el cierre (E2E-100 a E2E-109) las cubre.

   DOS MODOS: con Deno (DENO o /opt/node22/bin/deno) la función corre como en
   Supabase, en su puerto (8896; la de otro entorno, 8897), con npm:postgres
   contra la base; sin Deno (MODO NODE) se importa
   supabase/functions/contador/index.ts en este proceso (Node 22 quita los
   tipos) y la base es psql (usarBaseDePruebas, solo con MXP_BANCO_PRUEBAS=1).
   Lo que se prueba es el mismo atender(). El simulador escucha en 8895.

   Uso: node pruebas/conta/contador-e2e.mjs [bd=c8e2e] [puerto_pg=5433]
        CONSERVAR=1 deja la base; SIN_CONSTRUIR=1 usa una que ya existe y
        está como la deja la construcción de aquí (c8 pegado, sin
        propuestas, reglas ni ráfagas: p. ej. una copia hecha con «createdb
        -T c8base»; los cargos que ya esperen en su bandeja entran en la
        ráfaga y se cuentan: con una bandeja «como en producción», como la
        de c8b, la primera ráfaga sube max_por_rafaga lo justo para
        llevárselos todos —hasta 100— y lo devuelve a 20 en cuanto
        contesta); SIN_DENO=1 fuerza el modo node. Necesita el
        banco levantado (pruebas/conta/pg17.sh). Con Deno fuera de
        /opt/node22/bin: DENO=… (y su DENO_DIR con npm:postgres@3.4.5 en el
        caché). */
import { spawn, execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import path from 'node:path';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const R = path.resolve(AQUI, '../..');
const D = path.join(R, 'docs/conta');
const BD = process.argv[2] || 'c8e2e';
const PGPORT = process.argv[3] || process.env.PGPORT || '5433';
const PG_ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT, PGPASSWORD: 'editor_sql' };
const DENO = process.env.DENO || '/opt/node22/bin/deno';
const CON_DENO = !process.env.SIN_DENO && existsSync(DENO);
const P_SIM = 8895, P_FN = 8896, P_FN2 = 8897, P_MUERTO = '5499';
// Las llaves de prueba (nunca una de verdad): la buena y una que el simulador rechaza
const LLAVE = 'sk-ant-prueba', LLAVE_MALA = 'sk-ant-prueba-que-no-vale';
// (7b) la nota de unas horas de la cuadrilla: vive en la base y no debe salir de ella (ni a la IA, ni en una respuesta, ni en una tabla del contador)
const NOTA_SECRETA = 'E2E-C8 NOTA SECRETA DE LA CUADRILLA';
const UUID_NADA = '00000000-0000-4000-8000-000000000000';
const HOY = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
const diaMenos = (n) => new Date(Date.parse(`${HOY}T12:00:00Z`) - n * 86400_000).toISOString().slice(0, 10);
const RE_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// Todo lo que este proceso escribe pasa también por aquí: al final se busca
// la llave en la salida de la prueba, no solo en la de la función.
let salidaE2E = '';
const escribir = (m) => { salidaE2E += m + '\n'; console.log(m); };
const t0 = Date.now();
const log = (m) => escribir(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
const resultados = [];
const respuestas = []; // todo lo que contestó la función (para buscar llaves al final)
function ok(nombre, cond, detalle) {
  resultados.push({ nombre, ok: !!cond });
  escribir(`${cond ? ' ok ' : 'MAL '} ${nombre}${cond ? '' : ' — ' + String(typeof detalle === 'string' ? detalle : JSON.stringify(detalle ?? '')).slice(0, 1200)}`);
}
function q(sql) {
  return execFileSync('psql', ['-X', '-At', '-q', '-F', '|', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-c', sql], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20 }).toString().trim();
}
function qErr(sql) { try { return q(sql); } catch (e) { return 'error: ' + String(e.stderr || e.message).trim(); } }
const qj = (sql) => { const t = q(sql); return t ? JSON.parse(t) : null; };
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;
const sha256 = (s) => createHash('sha256').update(String(s)).digest('hex');
// psql asíncrono (la base del modo node, y lo que va a la vez)
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
// Una sentencia como un rol de la API (PostgREST): los claims de la sesión y el rol, en su transacción
function qComo(claims, rol, sql) {
  return qErr(`begin; do $$ begin perform set_config('request.jwt.claims', ${lit(JSON.stringify(claims))}, true);
                perform set_config('request.jwt.claim.sub', ${lit(claims.sub ?? '')}, true); end $$;
               ${rol ? `set local role ${rol};` : ''} ${sql}; commit;`);
}

// ---- 1. la base ----------------------------------------------------------
function psqlArchivo(archivo, extra = []) {
  return execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-f', archivo, ...extra], { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20 }).toString();
}
if (!process.env.SIN_CONSTRUIR) {
  log(`construyo ${BD} en el puerto ${PGPORT} (c1..c7, s1, p1 y c8: unos segundos)…`);
  const archivos = ['03-storage-simulacro.sql', ...['c1-plan-de-cuentas', 'c2-libro', 'c3-puentes', 'c4-estados', 'c6-banco'].map((f) => `../../docs/conta/${f}.sql`), '05-puentes-correr.sql'];
  try {
    execFileSync('./correr.sh', [BD, ...archivos], { cwd: AQUI, env: { ...process.env, PGHOST: '127.0.0.1', PGPORT }, stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) { console.error('correr.sh falló:\n' + (e.stdout?.toString().split('\n').slice(-15).join('\n') ?? '') + (e.stderr?.toString().slice(-2000) ?? '')); process.exit(2); }
  const su = process.env.BANCO_SU ? process.env.BANCO_SU.split(' ') : (process.getuid && process.getuid() === 0 ? ['runuser', '-u', 'postgres', '--', 'psql'] : ['psql', '-U', 'postgres']);
  const envSu = { ...process.env }; delete envSu.PGHOST;
  execFileSync(su[0], [...su.slice(1), '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-p', PGPORT, '-d', BD, '-f', path.join(R, 'pruebas/seguridad/00-vault-shim.sql')], { env: envSu, stdio: ['ignore', 'pipe', 'pipe'] });
  q(`select fn_tarjeta_alta('1007', '2100-2013', 'Amex Business Gold (prueba Plaid)')`);
  try { for (const f of ['c7-plaid', 's1-mfa', 'p1-stripe']) psqlArchivo(path.join(D, `${f}.sql`)); }
  catch (e) { console.error('c7, s1 o p1 falló:\n' + String(e.stderr || e.message).slice(-3000)); process.exit(2); }
  // las obras y las facturas de la semilla, en el libro (como la guía del lector 4 y stripe-e2e)
  q(`select fn_mapeo_confirmar('tipo_proyecto', 'residencial'); select fn_mapeo_confirmar('tipo_proyecto', 'comercial'); select fn_puentes_correr();`);
  log('c1..c7, s1 y p1 listos; c8-contador.sql dos veces…');
  let pegado = '';
  try { psqlArchivo(path.join(D, 'c8-contador.sql')); pegado = psqlArchivo(path.join(D, 'c8-contador.sql'), ['-At']); }
  catch (e) { console.error('c8-contador.sql falló:\n' + String(e.stderr || e.message).slice(-3000)); process.exit(2); }
  ok('E2E-01 c8-contador.sql entra dos veces (idempotente) y enseña su tabla final (claude-opus-5-5 · effort low, las cuentas, 0 cuadres rojos)',
     /contador_config\|claude-opus-5-5 · effort low · activa/.test(pegado) && /cuentas que se proponen\|\d+ \(v_contador_cuentas\)/.test(pegado) && /control\|0 cuadres rojos/.test(pegado)
     && /siguiente paso\|.*c8-pruebas\.sql/.test(pegado), pegado.slice(-900));
  log('c8-pruebas.sql…');
  let pruebasC8;
  try {
    pruebasC8 = execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-1', '-At', '-c', '\\o /dev/null', '-f', path.join(D, 'c8-pruebas.sql'), '-c', '\\o',
      '-c', `select format('total=%s ok=%s fallan=%s omitidas=%s', count(*), count(*) filter (where ok), count(*) filter (where not ok), count(*) filter (where ok is null)) || coalesce(' · ' || string_agg(n || ' ' || prueba, '; ') filter (where ok is not true), '') from _pruebas`],
      { env: PG_ENV, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 << 20 }).toString().trim();
  } catch (e) { pruebasC8 = 'error: ' + String(e.stderr || e.message).slice(-1500); }
  ok('E2E-02 c8-pruebas.sql en verde (32 de 32, con las de la 7b y las dos del 31-oct) y no deja nada (ni propuestas, ni reglas, ni ráfagas)',
     /^total=32 ok=32 fallan=0 omitidas=0/.test(pruebasC8) && q(`select (select count(*) from contador_propuestas) + (select count(*) from contador_reglas) + (select count(*) from contador_lotes)`) === '0', pruebasC8);
  // re-pegar las capas con c8 puesto: nada de c8 cuelga de sus vistas (las de c8 leen solo tablas)
  log('re-pego c1, c3, c4, c6, c7, s1 y p1 con c8 puesto, y c8 otra vez…');
  const repegar = [];
  for (const f of ['c1-plan-de-cuentas', 'c3-puentes', 'c4-estados', 'c6-banco', 'c7-plaid', 's1-mfa', 'p1-stripe', 'c8-contador']) {
    try { psqlArchivo(path.join(D, `${f}.sql`)); } catch (e) { repegar.push(`${f}: ${String(e.stderr || e.message).split('\n').find((l) => /ERROR/.test(l)) ?? 'falló'}`); }
  }
  ok('E2E-03 c1, c3, c4, c6, c7, s1 y p1 se vuelven a pegar con c8 puesto (sin MX000), y c8 una tercera vez', repegar.length === 0, repegar);
}
const dueno = q(`select id from perfiles where rol = 'dueno' and coalesce(activo, true) order by creado limit 1`);
const equipo = q(`select id from perfiles where rol <> 'dueno' and coalesce(activo, true) order by creado limit 1`);
const OBRAS = q(`select id || '|' || nombre from proyectos where estado in ('aprobado', 'ejecucion', 'pausa') order by nombre, id`).split('\n').filter(Boolean).map((l) => l.split('|'));
const [OBRA, OBRA_NOMBRE] = OBRAS[0] ?? [];
const [OBRA2, OBRA2_NOMBRE] = OBRAS[1] ?? [];
// (7b) OBRA3, la obra de las pistas de la primera ráfaga: una obra activa sin horas, tickets ni materiales de los
// últimos 60 días (en la semilla de pruebas/conta, Taller Ruiz), para que lo que pese en sus pistas sea solo lo que
// siembra esta prueba
const [OBRA3, OBRA3_NOMBRE] = (q(`select p.id || '|' || p.nombre from proyectos p
    where p.estado in ('aprobado', 'ejecucion', 'pausa') and p.id not in (${lit(OBRA ?? '')}, ${lit(OBRA2 ?? '')})
      and not exists (select 1 from horas h where h.proyecto_id = p.id and h.fecha > current_date - 60)
      and not exists (select 1 from recibos r where r.proyecto_id = p.id)
      and not exists (select 1 from materiales t where t.proyecto_id = p.id and t.creado > now() - interval '60 days')
    order by p.nombre, p.id limit 1`) || '').split('|');
const fresca = q(`select (select count(*) from contador_propuestas) || '|' || (select count(*) from contador_reglas) || '|' || (select count(*) from contador_lotes) || '|' || (select count(*) from movimientos_banco where id_externo like 'e2e-c8-%')`);
const cfg0 = q(`select modelo || '|' || effort || '|' || activa || '|' || max_por_rafaga || '|' || tope_mes_centavos || '|' || dueno || '|' || (ultima_rafaga_el is null) from contador_config where id = 1`);
ok('E2E-04 la base: dueño, equipo, tres obras activas (la tercera sin horas, tickets ni materiales recientes: la de las pistas de la 7b), c8 pegado (contador_config de fábrica: opus 5.5, low, activa, 20 por ráfaga, $30 al mes, el dueño, ninguna ráfaga) y sin propuestas, reglas ni ráfagas',
   dueno && equipo && OBRA && OBRA2 && OBRA3 && OBRA3_NOMBRE && fresca === '0|0|0|0' && cfg0 === `claude-opus-5-5|low|true|20|3000|${dueno}|true`, { dueno, equipo, OBRAS, OBRA3, fresca, cfg0 });
if (fresca !== '0|0|0|0') {
  console.error(`La base ${BD} ya se usó (propuestas|reglas|ráfagas|cargos e2e = ${fresca}): vuelve a clonarla (createdb -T c8base) o constrúyela (sin SIN_CONSTRUIR).`);
  process.exit(2);
}

// ---- 2. el Anthropic simulado y la función ---------------------------------
const hijos = [];
const limpiarHijos = () => { for (const h of hijos) { try { h.kill(); } catch { /* ya */ } } };
process.on('exit', limpiarHijos);
const simulador = spawn(process.execPath, [path.join(AQUI, 'contador-simulado.mjs'), String(P_SIM)], { stdio: ['ignore', 'pipe', 'inherit'], env: { ...process.env, ANTHROPIC_API_KEY: LLAVE } });
hijos.push(simulador);
await new Promise((res) => simulador.stdout.once('data', res));
const sim = async (ruta, cuerpo) => {
  const r = await fetch(`http://127.0.0.1:${P_SIM}${ruta}`, cuerpo ? { method: 'POST', body: JSON.stringify(cuerpo) } : {});
  const j = await r.json();
  if (!r.ok) throw new Error(`simulado ${ruta}: ${JSON.stringify(j)}`);
  return j;
};
const peticiones = async (desde = 0) => (await sim('/__peticiones')).peticiones.slice(desde);
const llamadasSim = async () => (await sim('/__estado')).llamadas;
const ENTORNO = {
  ANTHROPIC_API_KEY: LLAVE, ANTHROPIC_BASE_URL: `http://127.0.0.1:${P_SIM}`,
  MXP_DB_URL: `postgres://editor_sql:editor_sql@127.0.0.1:${PGPORT}/${BD}`, MXP_BANCO_PRUEBAS: '1', SUPABASE_URL: `http://127.0.0.1:${P_FN}`,
};
let salidaFn = '';
let atenderNode = null;
// El módulo se importa en los dos modos: en Deno, solo por sus piezas puras
// (_probar: las instrucciones, el esquema, armarPrefijo), que valen para
// comprobar lo que llega al simulador; no arranca nada (no hay Deno.serve aquí).
const modulo = await import(pathToFileURL(path.join(R, 'supabase/functions/contador/index.ts')).href);
const PR = modulo._probar;
// La base del modo node: psql por llamada, en su transacción, con los claims vacíos (como abrirBase)
function basePsql(puerto) {
  const dolar = (s) => { let tag = 'mxp'; while (s.includes(`$${tag}$`)) tag += 'x'; return `$${tag}$${s}$${tag}$`; };
  const literal = (v) => v === null || v === undefined ? 'NULL' : typeof v === 'number' ? String(v) : typeof v === 'boolean' ? String(v) : dolar(typeof v === 'string' ? v : JSON.stringify(v));
  return {
    async rpc(fn, args) {
      if (!/^fn_contador_[a-z_]+$/.test(fn)) throw Object.assign(new Error(`función que no es de c8: ${fn}`), { code: '42501' });
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
      if (!RE_UUID.test(carga?.sub ?? '')) return null;
      const r = await psqlAsync(`select rol || '|' || coalesce(activo, true) from perfiles where id = '${carga.sub}';`, puerto);
      // (la base caída no es «una sesión que no existe»: falla, como postgres.js en Deno)
      if (r.codigo !== 0) throw Object.assign(new Error(r.error.trim().split('\n')[0] || 'la base no contestó'), { code: '08006' });
      const [rol, activo] = r.salida.trim().split('|');
      return rol ? { id: carga.sub, rol, activo: activo === 't' || activo === 'true' } : null;
    },
  };
}
async function arrancarDeno(puerto, extra = {}) {
  const h = spawn(DENO, ['run', '--quiet', '-A', path.join(R, 'supabase/functions/contador/index.ts')], {
    stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...ENTORNO, ...extra, MXP_PUERTO: String(puerto) },
  });
  hijos.push(h);
  h.stdout.on('data', (d) => { salidaFn += d; }); h.stderr.on('data', (d) => { salidaFn += d; });
  for (let i = 0; i < 120; i++) {
    try { const r = await fetch(`http://127.0.0.1:${puerto}/?paso=salud`); if (r.ok) { await r.text(); return h; } } catch { /* todavía no */ }
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
  modulo.usarBaseDePruebas(basePsql(PGPORT));
  atenderNode = modulo.atender;
}
// Una llamada a la función (en Deno por HTTP; en node, a atender directo)
async function pedir(req, puerto = P_FN) {
  if (atenderNode) return await atenderNode(req);
  const u = new URL(req.url);
  return await fetch(`http://127.0.0.1:${puerto}${u.pathname}${u.search}`, { method: req.method, headers: req.headers, body: ['GET', 'OPTIONS'].includes(req.method) ? undefined : await req.text() });
}
async function llamar(cuerpo, { jwt: tok, metodo = 'POST', consulta = '', puerto, crudo } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (tok) headers.Authorization = `Bearer ${tok}`;
  const req = new Request(`http://127.0.0.1:${P_FN}/functions/v1/contador${consulta}`, { method: metodo, headers, body: ['GET', 'OPTIONS'].includes(metodo) ? undefined : (crudo ?? JSON.stringify(cuerpo)) });
  const r = await pedir(req, puerto);
  const texto = await r.text();
  respuestas.push(texto);
  let j = null; try { j = JSON.parse(texto); } catch { /* sin json */ }
  return { estado: r.status, j, cab: r.headers };
}
// Otra instancia con otro entorno (Deno: otro proceso; node: el entorno de este, un rato)
async function conEntorno(extra, fn) {
  if (!atenderNode) {
    const h = await arrancarDeno(P_FN2, extra);
    try { return await fn(P_FN2); } finally { h.kill(); await new Promise((r) => setTimeout(r, 150)); }
  }
  const antes = Object.fromEntries(Object.keys(extra).map((k) => [k, process.env[k]]));
  Object.assign(process.env, extra);
  try { return await fn(undefined); } finally { for (const [k, v] of Object.entries(antes)) { if (v === undefined) delete process.env[k]; else process.env[k] = v; } }
}
const b64u = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (sub, aal = 'aal2') => `${b64u({ alg: 'none', typ: 'JWT' })}.${b64u({ sub, role: 'authenticated', aal, exp: 4102444800 })}.firma`;
const D2 = jwt(dueno), D1 = jwt(dueno, 'aal1'), E2 = jwt(equipo), X2 = jwt(randomUUID());
const proponer = (extra = {}) => llamar({ accion: 'proponer', ...extra }, { jwt: D2 });

// Cargos como los trae Plaid (en nombre del dueño, como la sincronización de la
// mañana) y «Casar» de esa cuenta: sin ticket ni asiento que los explique,
// quedan «sin_ticket» en la bandeja. filas: [{clave, desc, monto (positivo =
// lo que salió), dias (hace cuántos)}]. Devuelve {clave: movimiento_id}.
let nSiembra = 0;
function sembrar(filas, cuenta = '1010') {
  nSiembra++;
  const conId = filas.map((f) => ({ ...f, id: `e2e-c8-${f.clave}` }));
  const lote = { origen: 'plaid', cuenta, nombre: `Plaid · e2e contador · ${nSiembra}`,
                 filas: conId.map((f) => ({ id: f.id, fecha: diaMenos(f.dias), plaid_monto: Number(f.monto).toFixed(2), descripcion: f.desc, tipo: 'DEBIT', pendiente: false })) };
  execFileSync('psql', ['-X', '-At', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-f', '-'], { env: PG_ENV, stdio: ['pipe', 'pipe', 'pipe'], input: `begin;
    select set_config('request.jwt.claims', ${lit(JSON.stringify({ sub: dueno, role: 'authenticated' }))}, true) as a, set_config('request.jwt.claim.sub', ${lit(dueno)}, true) as b \\gset x_
    select fn_banco_importar_filas(${lit(JSON.stringify(lote))}::jsonb) is not null as i \\gset x_
    select fn_banco_casar_todo(${lit(cuenta)}) is not null as c \\gset x_
    commit;` });
  return Object.fromEntries(conId.map((f) => [f.clave, q(`select id from movimientos_banco where id_externo = ${lit(f.id)} order by importado_el desc limit 1`)]));
}
// «Des-casar» en la bandeja (en nombre del dueño): el asiento de c6 se reversa y el movimiento vuelve a pendiente
function descasar(mov, motivo) {
  return qErr(`begin; do $$ begin perform set_config('request.jwt.claims', ${lit(JSON.stringify({ sub: dueno, role: 'authenticated' }))}, true);
                perform set_config('request.jwt.claim.sub', ${lit(dueno)}, true); end $$;
               select fn_banco_descasar(${lit(mov)}, ${lit(motivo)}) is not null; commit;`);
}
// La última propuesta de un movimiento (o null), entera
const propDe = (mov) => qj(`select row_to_json(p)::text from (select * from contador_propuestas where movimiento_id = ${lit(mov)} order by creado_el desc, id desc limit 1) p`);
const pendienteDe = (mov) => q(`select coalesce((select id::text from contador_propuestas where movimiento_id = ${lit(mov)} and estado = 'pendiente'), '')`);
const estadoMov = (mov) => q(`select estado || '|' || coalesce(asiento_id::text, '-') from movimientos_banco where id = ${lit(mov)}`);
const lineasDe = (asiento) => q(`select string_agg(l.cuenta || ' ' || l.monto || coalesce(' @' || l.proyecto_id, ''), ' | ' order by l.cuenta, l.monto) from asiento_lineas l where l.asiento_id = ${lit(asiento)}`);
const asientoVivo = (asiento) => q(`select count(*) from asientos a where a.id = ${lit(asiento)} and not exists (select 1 from asientos r where r.reversa_a = a.id and r.camino in ('reverso', 'reverso_automatico'))`) === '1';
const control = () => qj(`select coalesce(json_agg(json_build_object('orden', orden, 'control', control, 'nivel', nivel, 'ok', ok, 'detalle', detalle) order by orden), '[]')::text from v_contador_control`);
const rojos = (nivel) => control().filter((c) => c.nivel === nivel && !c.ok).map((c) => `${c.orden} ${c.control}: ${c.detalle ?? ''}`);
const gastoContador = () => q(`select coalesce(sum(centavos), 0) || '|' || coalesce(sum(llamadas), 0) from asistente_costo_mes where accion = 'contador_categorizar' and mes = to_char(fn_fecha_miami(now()), 'YYYY-MM')`).split('|').map(Number);
const contenido = (p) => p?.cuerpo?.messages?.[0]?.content ?? '';
const msgDe = (p) => { try { return JSON.parse(contenido(p)); } catch { return null; } };
// (la clave de un cargo en lo que llega a la IA: su cuenta, su fecha, su desc_norm y su monto; la bandeja «como en
// producción» repite comercio y monto en días distintos)
const claveMsg = (p) => { const m = msgDe(p); return m ? `${m.cuenta_banco}|${m.fecha}|${m.desc_norm}|${m.monto}` : '?'; };
const centavosDe = (u) => Math.round((u.input * 400 + u.cache_creacion * 500 + u.cache_lectura * 20 + u.output * 2000) / 1_000_000);
const usoSim = (ps) => ps.filter((p) => p.respuesta?.usage).reduce((s, p) => ({ input: s.input + p.respuesta.usage.input_tokens, output: s.output + p.respuesta.usage.output_tokens,
  cache_creacion: s.cache_creacion + p.respuesta.usage.cache_creation_input_tokens, cache_lectura: s.cache_lectura + p.respuesta.usage.cache_read_input_tokens }), { input: 0, output: 0, cache_creacion: 0, cache_lectura: 0 });
// (los hashes que la base guarda en «entrada» —prompt_version, prefijo_hash, reglas_version— van enteros: la máscara de
// datos personales no toca un hash ni esas tres claves; E2E-49 los compara con ===)
// Un esquema cerrado: cada objeto con additionalProperties false y todas sus propiedades en required
function esquemaCerrado(s) {
  if (!s || typeof s !== 'object') return true;
  const tipos = Array.isArray(s.type) ? s.type : [s.type];
  if (tipos.includes('object')) {
    if (s.additionalProperties !== false) return false;
    if (!isDeepStrictEqual([...(s.required ?? [])].sort(), Object.keys(s.properties ?? {}).sort())) return false;
  }
  return Object.values(s.properties ?? {}).every(esquemaCerrado) && (s.items ? esquemaCerrado(s.items) : true);
}
// En qué grupos de la ráfaga llegaron las peticiones: la primera sola y después de tres en tres
const trozos = (xs) => xs.length ? [xs.slice(0, 1), ...Array.from({ length: Math.ceil((xs.length - 1) / 3) }, (_, i) => xs.slice(1 + i * 3, 4 + i * 3))] : [];
const mismoConjunto = (a, b) => isDeepStrictEqual([...a].sort(), [...b].sort());

try {
  // ---- E2E-05 la siembra ---------------------------------------------------------
  log('siembro los cargos de la primera ráfaga (Plaid + «Casar»)…');
  const M = sembrar([
    { clave: 'hd', desc: 'THE HOME DEPOT 6341 OCALA FL', monto: 87.43, dias: 6 },
    { clave: 'wawa', desc: 'WAWA 5213 TAMPA FL', monto: 54.10, dias: 5 },
    { clave: 'irs', desc: 'IRS USATAXPYMT 240415', monto: 1200.00, dias: 5 },
    { clave: 'amz', desc: 'AMAZON MKTPL*2K3J CAIDO', monto: 38.20, dias: 4 },
    { clave: 'nfx', desc: 'NETFLIX.COM REFUSAL', monto: 15.49, dias: 4 },
    { clave: 'roto', desc: 'ROTO STORE 1', monto: 22.00, dias: 4 },
    { clave: 'inv', desc: 'INVALIDA SHOP 77', monto: 19.00, dias: 3 },
    { clave: 'max', desc: 'MAXTOKENS SHOP 5', monto: 33.00, dias: 3 },
    { clave: 'ally', desc: 'ALLY AUTO LOAN PMT', monto: 412.33, dias: 3 },
    { clave: 'dell', desc: 'DELL MARKETING L.P. 800-624-9897 TX', monto: 3150.00, dias: 2 },
    { clave: 'zelle', desc: 'ZELLE PAYMENT TO JUAN PEREZ JPEREZ@MAIL.COM 305-555-1234 ACCT 1234567890', monto: 600.00, dias: 2 },
    { clave: 'nfpa', desc: 'NFPA NATL FIRE PROTECTION 1 BATTERYMARCH PARK', monto: 175.00, dias: 2 },
  ]);
  const sembrados = Object.values(M);
  ok('E2E-05 doce cargos sembrados por Plaid y «Casar»: todos pendientes con motivo «sin_ticket» en la bandeja',
     sembrados.every((m) => RE_UUID.test(m)) && q(`select count(*) from v_banco_bandeja where motivo = 'sin_ticket' and movimiento_id in (${sembrados.map(lit).join(', ')})`) === '12', M);
  // (7b) LAS PISTAS DEL HOME DEPOT, sembradas aquí: la cuadrilla reportó 24 h en OBRA3 (8 h al día de 8 a 6 días atrás, a
  // nombre del equipo; una fila con la nota que no debe salir de la base), alrededor de su cargo (hace 6 días: ±3 días) y
  // fuera de los ±3 días del Zelle (hace 2). LAS CUENTAS, para cualquier día en que se corra: el HOME DEPOT suma en
  // OBRA3 24×2 + 24×0,2 = 52,8 puntos; la semilla, con fecha fija, le da a lo sumo 6 + 3,9 a la oficina (el ticket de
  // Home Depot y sus 19,5 h del mes) y 6 a la casa (30 h): OBRA3 dobla a cualquiera y es la candidata, con el motivo
  // «la cuadrilla reportó 24 h en OBRA3 esos días» tal cual. El Zelle solo ve esas 24 h en el mes (4,8 puntos) y la
  // semilla no le da 8 a nadie: sin candidata, pide obra. Y el siguiente HOME DEPOT (hace 1 día, E2E-116): la oficina
  // suma 10 por lo que Edgar elige en E2E-63 más los 6 de su ticket, contra 4,8 de OBRA3 y ≤ 6 de la casa (y cuando
  // ese ticket salga de sus 180 días, 10 contra 4,8: sigue doblando).
  q(`insert into horas (fecha, usuario_id, proyecto_id, horas, notas) values
       (${lit(diaMenos(8))}, ${lit(equipo)}, ${lit(OBRA3)}, 8, ${lit(NOTA_SECRETA)}),
       (${lit(diaMenos(7))}, ${lit(equipo)}, ${lit(OBRA3)}, 8, null),
       (${lit(diaMenos(6))}, ${lit(equipo)}, ${lit(OBRA3)}, 8, null)`);
  const cands0 = Number(q(`select count(*) from fn_contador_candidatos()`));
  ok('E2E-06 antes de la primera ráfaga, la alarma 73 («la llave y la función») está en rojo: cargos de hace más de dos días y ninguna ráfaga',
     rojos('alarma').some((x) => /^73 ia: la llave y la función: ninguna ráfaga ha corrido nunca/.test(x)) && rojos('cuadre').length === 0, control());

  // ---- E2E-07 salud, CORS, el banco de pruebas ----------------------------------------
  const PV = sha256(PR.INSTRUCCIONES);
  let r = await llamar(null, { metodo: 'GET', consulta: '?paso=salud' });
  ok('E2E-07 salud (GET, sin sesión): ok, llave, base, banco de pruebas, claude-opus-5-5, effort low, activa, 20 por ráfaga, la versión 2023-06-01, max_tokens 4096, nada falta',
     r.estado === 200 && r.j.ok === true && r.j.llave === true && r.j.base === true && r.j.banco_de_pruebas === true && r.j.modelo === 'claude-opus-5-5' && r.j.effort === 'low'
     && r.j.activa === true && r.j.max_por_rafaga === 20 && r.j.version === '2023-06-01' && r.j.max_tokens === 4096 && PR.MAX_TOKENS === 4096 && Array.isArray(r.j.falta) && r.j.falta.length === 0, r.j);
  ok(`E2E-08 salud: prompt_version = sha256 de las instrucciones (${PR.INSTRUCCIONES.length} letras, con las pistas de la obra de la 7b); el tope del mes sin bloquear; ninguna ráfaga todavía`,
     r.j.prompt_version === PV && PR.INSTRUCCIONES.length > 3000 && PR.INSTRUCCIONES.includes('pistas_obra') && r.j.tope?.bloqueado === false && r.j.tope.tope_contador === 3000 && typeof r.j.tope.centavos_mes_total === 'number'
     && r.j.ultima_rafaga_el === null && r.j.con_error === false, r.j);
  ok('E2E-09 salud no enseña la llave ni nada del libro (ninguna descripción del banco) y lleva CORS',
     !JSON.stringify(r.j).includes('sk-ant') && !/HOME DEPOT|WAWA|NETFLIX|ZELLE/.test(JSON.stringify(r.j)) && r.cab.get('access-control-allow-origin') === '*', r.j);
  r = await llamar(null, { metodo: 'OPTIONS' });
  ok('E2E-10 OPTIONS → 204 con CORS (origen *, cabeceras authorization y content-type, GET/POST/OPTIONS)',
     r.estado === 204 && r.cab.get('access-control-allow-origin') === '*' && /authorization/.test(r.cab.get('access-control-allow-headers') ?? '')
     && /content-type/.test(r.cab.get('access-control-allow-headers') ?? '') && /POST/.test(r.cab.get('access-control-allow-methods') ?? ''), [r.estado, Object.fromEntries(r.cab)]);
  r = await conEntorno({ ANTHROPIC_API_KEY: '' }, (p) => llamar(null, { metodo: 'GET', consulta: '?paso=salud', puerto: p }));
  ok('E2E-11 salud sin ANTHROPIC_API_KEY: llave false y «falta» lo dice (cómo crearla), la base sigue', r.estado === 200 && r.j.llave === false && r.j.base === true
     && r.j.falta.some((f) => /ANTHROPIC_API_KEY.*console\.anthropic\.com/.test(f)), r.j);
  const FUERA = 'postgres://u:p@db.ejemplo-prod.supabase.co:5432/postgres';
  const r11a = await conEntorno({ MXP_DB_URL: FUERA }, (p) => llamar(null, { metodo: 'GET', consulta: '?paso=salud', puerto: p }));
  const r11b = await conEntorno({ MXP_DB_URL: FUERA }, (p) => llamar({ accion: 'estado' }, { jwt: D2, puerto: p }));
  const r11c = await conEntorno({ SUPABASE_DB_URL: FUERA }, (p) => llamar({ accion: 'proponer' }, { jwt: D2, puerto: p }));
  ok('E2E-12 MXP_BANCO_PRUEBAS fuera del banco (la base no es 127.0.0.1, o hay SUPABASE_DB_URL): salud lo dice y todo → 500 CONFIG, sin tocar la base ni Anthropic',
     r11a.estado === 200 && r11a.j.banco_de_pruebas === false && r11a.j.base === false && r11a.j.falta.some((f) => /MXP_BANCO_PRUEBAS no vale/.test(f))
     && r11b.estado === 500 && r11b.j.codigo === 'CONFIG' && /MXP_BANCO_PRUEBAS/.test(r11b.j.error) && r11c.estado === 500 && r11c.j.codigo === 'CONFIG'
     && (await llamadasSim()) === 0, [r11a.j, r11b.j, r11c.j]);

  // ---- E2E-13 quién ------------------------------------------------------------------
  r = await llamar({ accion: 'estado' });
  const r13 = await llamar({ accion: 'proponer' });
  ok('E2E-13 sin sesión → 401 SESION «Entra con tu sesión.» (estado y proponer)', r.estado === 401 && r.j.codigo === 'SESION' && /Entra con tu sesión/.test(r.j.error) && r13.estado === 401, [r, r13]);
  r = await llamar({ accion: 'estado' }, { jwt: X2 });
  const r14 = await llamar({ accion: 'estado' }, { jwt: 'no-es-un-jwt' });
  ok('E2E-14 una sesión de nadie (sub que no está en perfiles) o un JWT roto → 401 SESION', r.estado === 401 && r.j.codigo === 'SESION' && r14.estado === 401 && r14.j.codigo === 'SESION', [r, r14]);
  r = await llamar({ accion: 'proponer' }, { jwt: E2 });
  const r15 = await llamar({ accion: 'regla_alta', nombre: 'X', patron: '^X', lineas: [{ cuenta: '6300' }] }, { jwt: E2 });
  ok('E2E-15 el equipo (aal2) → 403 NO_DUENO (proponer, regla_alta)', r.estado === 403 && r.j.codigo === 'NO_DUENO' && r15.estado === 403 && r15.j.codigo === 'NO_DUENO', [r, r15]);
  r = await llamar({ accion: 'proponer' }, { jwt: D1 });
  const r16 = await llamar({ accion: 'estado' }, { jwt: D1 });
  ok('E2E-16 el dueño sin el código del teléfono (aal1) → 403 MFA (proponer y estado)', r.estado === 403 && r.j.codigo === 'MFA' && /código del teléfono/.test(r.j.error) && r16.estado === 403 && r16.j.codigo === 'MFA', [r, r16]);
  r = await llamar(null, { jwt: D2, crudo: '{esto no es JSON' });
  const r17 = await llamar({ accion: 'nada' }, { jwt: D2 });
  ok('E2E-17 un cuerpo que no es JSON → 400 FORMA; una acción desconocida → 400 ACCION', r.estado === 400 && r.j.codigo === 'FORMA' && r17.estado === 400 && r17.j.codigo === 'ACCION', [r, r17]);
  r = await llamar({ accion: 'estado' }, { jwt: D2 });
  ok('E2E-18 estado (el dueño en aal2): la salud, la fila de v_contador_estado (instalado, lo que espera), el tope y el control en rojo (la alarma 73)',
     r.estado === 200 && r.j.ok && r.j.salud?.ok && r.j.salud.base && r.j.estado?.instalado === true && Number(r.j.estado.pendientes_sin_propuesta) === cands0
     && Number(r.j.estado.propuestas_pendientes) === 0 && r.j.tope?.bloqueado === false && r.j.control_rojo.some((c) => c.orden === 73) && !r.j.control_rojo.some((c) => c.nivel === 'cuadre'), r.j);
  ok('E2E-19 nada de eso llamó a Anthropic, abrió una ráfaga ni guardó una propuesta', (await llamadasSim()) === 0 && q(`select (select count(*) from contador_lotes) + (select count(*) from contador_propuestas)`) === '0');

  // ---- E2E-20 una regla de Edgar antes de la primera ráfaga ------------------------------------
  const casanNfpa = Number(q(`select count(*) from fn_contador_candidatos() where desc_norm ~* '^NFPA'`));
  r = await llamar({ accion: 'regla_alta', nombre: 'NFPA', patron: '^NFPA', lineas: [{ cuenta: '6800' }] }, { jwt: D2 });
  const reglaNfpa = r.j?.regla?.id;
  ok('E2E-20 regla_alta (Edgar dicta «NFPA → 6800»): activa, origen edgar, y dice con cuántos de los que esperan casa ahora',
     r.estado === 200 && r.j.regla?.activa === true && r.j.regla.origen === 'edgar' && r.j.regla.patron === '^NFPA' && r.j.regla.casan_ahora === casanNfpa && casanNfpa >= 1
     && r.j.regla.creada_por === dueno && r.j.regla.pide_obra === false, r.j);
  const malas21 = [
    ['un patrón roto «(»', await llamar({ accion: 'regla_alta', nombre: 'Mala', patron: '(', lineas: [{ cuenta: '6300' }] }, { jwt: D2 }), 409, '22023'],
    ['un patrón que casa con todo «.*»', await llamar({ accion: 'regla_alta', nombre: 'Todo', patron: '.*', lineas: [{ cuenta: '6300' }] }, { jwt: D2 }), 409, '22023'],
    ['la cuenta 6000 (sueldos: solo por nómina)', await llamar({ accion: 'regla_alta', nombre: 'Sueldo', patron: '^PAYROLL X', lineas: [{ cuenta: '6000' }] }, { jwt: D2 }), 409, 'MX004'],
    ['cuenta_banco 1130 (no es un banco ni una tarjeta)', await llamar({ accion: 'regla_alta', nombre: 'Banco raro', patron: '^RARO X', lineas: [{ cuenta: '6300' }], cuenta_banco: '1130' }, { jwt: D2 }), 409, 'MX004'],
    ['dos líneas cuyas partes no suman 1', await llamar({ accion: 'regla_alta', nombre: 'Partes', patron: '^PARTES X', lineas: [{ cuenta: '2520', parte: 0.5 }, { cuenta: '7100', parte: 0.2 }] }, { jwt: D2 }), 409, 'MX001'],
    ['sin nombre', await llamar({ accion: 'regla_alta', patron: '^SIN NOMBRE', lineas: [{ cuenta: '6300' }] }, { jwt: D2 }), 400, 'FORMA'],
  ];
  ok('E2E-21 regla_alta frena en llano: patrón roto o que casa con todo (22023), 6000 o una cuenta_banco que no es banco (MX004), partes que no suman (MX001), sin nombre (400) — y no entra ninguna',
     malas21.every(([, x, e, c]) => x.estado === e && x.j?.codigo === c && typeof x.j.error === 'string') && q(`select count(*) from contador_reglas`) === '1',
     malas21.filter(([, x, e, c]) => !(x.estado === e && x.j?.codigo === c)).map(([n, x]) => [n, x.estado, x.j]));

  // ---- E2E-22 LA PRIMERA RÁFAGA ---------------------------------------------------------------
  // (la clave de cada cargo: su cuenta, su fecha, su desc_norm tal cual se le da a la IA —fn_contador_sin_datos_norm, con la
  // descripción cruda— y su monto)
  const iaCands = qj(`select coalesce(json_agg(json_build_object('id', movimiento_id, 'clave', cuenta || '|' || fecha || '|' || fn_contador_sin_datos_norm(desc_norm, descripcion, memo) || '|' || monto::float8, 'cuenta', cuenta) order by fecha, importado_el, movimiento_id), '[]')::text
                        from fn_contador_candidatos() where not (desc_norm ~* '^NFPA')`);
  const claveDeMov = Object.fromEntries(iaCands.map((c) => [c.id, c.clave]));
  const asientos0 = q(`select count(*) from asientos`);
  const gasto0 = gastoContador();
  await sim('/__reiniciar');
  await sim('/__lento', { ms: 150 });
  // (una base clonada con cargos que ya esperaban —c8b: la bandeja «como en producción»— entra entera en la primera
  // ráfaga: max_por_rafaga sube lo justo solo para ella, hasta 100, y vuelve a 20 en cuanto contesta)
  const maxPrimera = Math.max(20, iaCands.length);
  if (maxPrimera > 20) q(`update contador_config set max_por_rafaga = ${maxPrimera} where id = 1`);
  log(`primera ráfaga: ${iaCands.length} a la IA y ${casanNfpa} por regla${maxPrimera > 20 ? ` (max_por_rafaga ${maxPrimera} solo para ella)` : ''}…`);
  r = await proponer();
  if (maxPrimera > 20) q(`update contador_config set max_por_rafaga = 20 where id = 1`);
  const P1 = r.j ?? {};
  // (si la ráfaga no abrió lote, las consultas siguen con un uuid que no existe: salen en rojo sin reventar)
  const LOTE1 = RE_UUID.test(P1.lote ?? '') ? P1.lote : '00000000-0000-4000-8000-000000000000';
  const pet1 = await peticiones();
  const est1 = await sim('/__estado');
  ok('E2E-22 proponer → 200: no bloqueado, el lote, opus 5.5 / low, la versión del prompt y el hash del prefijo, y los conteos (propuestas + sin respuesta + inválidas = movimientos)',
     r.estado === 200 && P1.ok === true && P1.bloqueado === false && RE_UUID.test(P1.lote ?? '') && P1.modelo === 'claude-opus-5-5' && P1.effort === 'low' && P1.prompt_version === PV
     && /^[0-9a-f]{64}$/.test(P1.prefijo_hash ?? '') && P1.movimientos === iaCands.length && P1.total === iaCands.length
     && P1.propuestas + P1.sin_respuesta + P1.invalidas === P1.movimientos && P1.reglas === casanNfpa, { ...P1, detalle: undefined });
  const nfpaProp = propDe(M.nfpa);
  ok('E2E-23 la regla contesta antes que la IA: NFPA queda pendiente por regla (confianza 1, «Regla: NFPA», 6800, su regla_id), suma veces, y ninguna petición a la IA lo lleva',
     nfpaProp?.estado === 'pendiente' && nfpaProp.fuente === 'regla' && nfpaProp.regla_id === reglaNfpa && nfpaProp.propuesta.confianza === 1 && nfpaProp.propuesta.motivo === 'Regla: NFPA'
     && isDeepStrictEqual(nfpaProp.propuesta.lineas, [{ cuenta: '6800' }]) && nfpaProp.lote_id === null && q(`select veces || '|' || (ultima_vez is not null) from contador_reglas where id = ${lit(reglaNfpa)}`) === `${casanNfpa}|true`
     && !pet1.some((p) => /NFPA/.test(p.cuerpo?.messages?.[0]?.content ?? '')), nfpaProp);
  const repetidas = pet1.filter((p, i) => pet1.findIndex((x) => claveMsg(x) === claveMsg(p)) !== i);
  ok('E2E-24 la ráfaga llama a la IA UNA vez por movimiento (más el reintento del 529: AMAZON CAIDO, dos veces)',
     pet1.length === iaCands.length + 1 && repetidas.length === 1 && /AMAZON/.test(repetidas[0]?.cuerpo?.messages?.[0]?.content ?? '')
     && mismoConjunto([...new Set(pet1.map(claveMsg))], iaCands.map((c) => c.clave)), { pedidas: pet1.length, esperadas: iaCands.length + 1, repetidas: repetidas.map(claveMsg) });
  const primeras = pet1.filter((p, i) => pet1.findIndex((x) => claveMsg(x) === claveMsg(p)) === i);
  const tE = trozos(iaCands.map((c) => c.clave)), tP = trozos(primeras.map(claveMsg));
  ok('E2E-25 los más viejos primero: la primera petición es el cargo más viejo y cada grupo de la ráfaga trae los que siguen, en orden',
     tE.length === tP.length && tE.every((t, i) => mismoConjunto(t, tP[i])) && claveMsg(pet1[0]) === iaCands[0].clave, { esperado: tE, llegó: tP });
  const grupoDe = new Map(); tP.forEach((t, i) => t.forEach((k) => grupoDe.set(k, i)));
  const porGrupo = tP.map((_, i) => pet1.filter((p) => grupoDe.get(claveMsg(p)) === i));
  const enOrden = porGrupo.every((g, i) => i === 0 || Math.min(...g.map((p) => p.llegada_ms)) >= Math.max(...porGrupo[i - 1].map((p) => p.terminada_ms)));
  ok('E2E-26 la PRIMERA llamada va sola (crea el caché): nada más en vuelo y la segunda llega cuando ya contestó',
     pet1[0]?.en_vuelo === 0 && pet1.slice(1).every((p) => p.llegada_ms >= pet1[0].terminada_ms), pet1.map((p) => [p.n, p.en_vuelo, p.llegada_ms, p.terminada_ms]));
  ok('E2E-27 las demás de TRES en tres: nunca más de tres a la vez, los grupos de tres se pisan de verdad, y un grupo no sale hasta que el anterior contestó',
     est1.max_en_vuelo === 3 && pet1.every((p) => p.en_vuelo <= 2) && porGrupo.some((g) => g.some((p) => p.en_vuelo === 2)) && enOrden,
     { max_en_vuelo: est1.max_en_vuelo, grupos: porGrupo.map((g) => g.map((p) => [p.en_vuelo, p.llegada_ms, p.terminada_ms])) });
  ok('E2E-28 las cabeceras: la llave buena (x-api-key), anthropic-version 2023-06-01, content-type JSON y ninguna anthropic-beta',
     pet1.every((p) => p.cabeceras['x-api-key'] === 'ok' && p.cabeceras['anthropic-version'] === '2023-06-01' && /^application\/json/.test(p.cabeceras['content-type'] ?? '') && p.cabeceras['anthropic-beta'] === null),
     pet1.map((p) => p.cabeceras));
  ok('E2E-29 el cuerpo: solo model (claude-opus-5-5), max_tokens 4096 (el pensamiento adaptativo cuenta contra él), system, messages y output_config — sin thinking, tool_choice, fallbacks, temperature, tools ni stream',
     pet1.every((p) => mismoConjunto(Object.keys(p.cuerpo ?? {}), ['model', 'max_tokens', 'system', 'messages', 'output_config']) && p.cuerpo.model === 'claude-opus-5-5' && p.cuerpo.max_tokens === 4096),
     pet1.map((p) => Object.keys(p.cuerpo ?? {})));
  const esquema = pet1[0]?.cuerpo?.output_config?.format?.schema;
  // (7b) «obra»: un objeto cerrado {proyecto_id, confianza, motivo} o null, como lista de tipos —la forma de monto y
  // proyecto_id— o como anyOf con {type: "null"}, la otra que la función deja escrita por si la API la pidiera
  const obraEsq = esquema?.properties?.obra;
  const obraObj = Array.isArray(obraEsq?.anyOf) ? obraEsq.anyOf.find((x) => x?.type === 'object') : obraEsq;
  const obraNula = Array.isArray(obraEsq?.anyOf) ? obraEsq.anyOf.some((x) => x?.type === 'null') : [].concat(obraEsq?.type ?? []).includes('null');
  ok('E2E-30 output_config = {effort: "low", format: {type: "json_schema", schema}}: el esquema de la función, cerrado (additionalProperties false y todo required en cada objeto), y desde la 7b «obra» en required: {proyecto_id, confianza, motivo} cerrado, o null',
     pet1.every((p) => mismoConjunto(Object.keys(p.cuerpo.output_config ?? {}), ['effort', 'format']) && p.cuerpo.output_config?.effort === 'low' && p.cuerpo.output_config?.format?.type === 'json_schema'
       && isDeepStrictEqual(p.cuerpo.output_config?.format?.schema, JSON.parse(JSON.stringify(PR.PROPUESTA_SCHEMA))))
     && esquemaCerrado(esquema) && mismoConjunto(esquema?.required ?? [], ['lineas', 'motivo', 'confianza', 'flags', 'alternativas', 'obra'])
     && mismoConjunto(esquema?.properties?.flags?.required ?? [], ['capitalizable', 'use_tax', 'personal', 'irs', 'pide_obra'])
     && obraNula && esquemaCerrado(obraObj) && [].concat(obraObj?.type ?? []).includes('object') && mismoConjunto(obraObj?.required ?? [], ['proyecto_id', 'confianza', 'motivo'])
     && obraObj.properties?.proyecto_id?.type === 'string' && obraObj.properties?.confianza?.type === 'number' && obraObj.properties?.motivo?.type === 'string', pet1[0]?.cuerpo?.output_config);
  const prefijo1 = pet1[0]?.cuerpo?.system?.[0]?.text ?? '';
  const ctx1 = qj(`select (fn_contador_pendientes(1)->'contexto')::text`);
  const ctas = q(`select string_agg(codigo, ' ' order by codigo) from v_contador_cuentas`).split(' ');
  ok('E2E-31 system: UN bloque de texto con cache_control ephemeral, el MISMO prefijo en todas las peticiones, y su sha256 es el prefijo_hash de la ráfaga',
     pet1.every((p) => Array.isArray(p.cuerpo.system) && p.cuerpo.system.length === 1 && p.cuerpo.system[0].type === 'text' && isDeepStrictEqual(p.cuerpo.system[0].cache_control, { type: 'ephemeral' })
       && p.cuerpo.system[0].text === prefijo1) && sha256(prefijo1) === P1.prefijo_hash && new Set(pet1.map((p) => p.prefijo?.sha256)).size === 1, pet1[0]?.cuerpo?.system?.map((s) => ({ ...s, text: s.text?.length })));
  ok('E2E-32 el prefijo es determinista: = armarPrefijo(el contexto de fn_contador_pendientes), empieza por las instrucciones, sin fechas ni uuids, y pasa de los 512 tokens del caché',
     prefijo1 === PR.armarPrefijo(ctx1) && prefijo1.startsWith(PR.INSTRUCCIONES + '\n\n') && !pet1[0].prefijo?.tiene_fecha && !pet1[0].prefijo?.tiene_uuid && pet1[0].prefijo?.tokens >= 512,
     { iguales: prefijo1 === PR.armarPrefijo(ctx1), prefijo: pet1[0]?.prefijo });
  // (la cabecera de la sección: las instrucciones también nombran «el PLAN DE CUENTAS PERMITIDO de abajo»)
  const lineasPlan = prefijo1.split('\n\nPLAN DE CUENTAS PERMITIDO (')[1]?.split('\n\n')[0]?.split('\n').slice(1) ?? [];
  ok('E2E-33 el prefijo lleva el plan PERMITIDO entero (v_contador_cuentas, una línea por cuenta, 5100 con obra obligatoria) y nunca 6000, un banco (1010), 1110, 2010 ni una tarjeta',
     lineasPlan.length === ctas.length && ctas.every((c, i) => lineasPlan[i].startsWith(`${c} · `)) && lineasPlan.some((l) => /^5100 · .* · costo · obra obligatoria/.test(l))
     && !lineasPlan.some((l) => /^(6000|1010|1110|2010|2100-\d+) · /.test(l)), lineasPlan.slice(0, 5));
  ok('E2E-34 …las obras activas (id · nombre · estado), la regla de Edgar (NFPA: 6800, patrón ^NFPA) y los ejemplos',
     OBRAS.every(([id, nombre]) => prefijo1.includes(`\n${id} · ${nombre} · `)) && /REGLAS DE EDGAR[^\n]*:\nNFPA: 6800 \(patrón \^NFPA\)/.test(prefijo1) && /EJEMPLOS DE EDGAR/.test(prefijo1),
     prefijo1.slice(prefijo1.lastIndexOf('OBRAS ACTIVAS'), prefijo1.lastIndexOf('OBRAS ACTIVAS') + 600));
  const msgs = pet1.map(msgDe);
  const CLAVES_MSG = ['fecha', 'monto', 'descripcion', 'memo', 'cuenta_banco', 'cuenta_banco_nombre', 'tipo_banco', 'desc_norm', 'pistas_obra'];
  ok('E2E-35 messages: UN turno user cuyo contenido es el JSON del movimiento (fecha, monto en negativo, descripción, nota, cuenta del banco y su nombre, tipo, desc_norm y, desde la 7b, pistas_obra: E2E-110)',
     pet1.every((p, i) => p.cuerpo.messages?.length === 1 && p.cuerpo.messages[0].role === 'user' && typeof contenido(p) === 'string' && msgs[i]
       && mismoConjunto(Object.keys(msgs[i]), CLAVES_MSG) && /^\d{4}-\d{2}-\d{2}$/.test(msgs[i].fecha) && msgs[i].monto < 0 && /^(10\d\d|2100-\d+)$/.test(msgs[i].cuenta_banco)),
     msgs.slice(0, 2));
  const todo1 = JSON.stringify(pet1.map((p) => p.cuerpo)).toUpperCase();
  // (también el correo como lo deja c6 al normalizar —«JPEREZ MAIL COM»— y su usuario solo)
  const prohibidos = ['JPEREZ@MAIL.COM', 'JPEREZ MAIL COM', 'JPEREZ', 'MAIL COM', '305-555-1234', '305 555 1234', '1234567890', '800-624-9897', '800 624 9897', '888 865 5352', '21813524', '800 344 3555'];
  // (el Zelle y el Dell de esta prueba, por su clave: la bandeja «como en producción» trae otros Zelle a la misma persona)
  const msgDeClave = (k) => msgs.find((m, i) => m && claveMsg(pet1[i]) === k);
  const zelleMsg = msgDeClave(claveDeMov[M.zelle]);
  const dellMsg = msgDeClave(claveDeMov[M.dell]);
  ok('E2E-36 a la IA nunca le llega un correo, un teléfono ni un número de cuenta (la base los tapa, también en desc_norm, donde c6 ya había deshecho el correo): el Zelle va con su nombre del banco y [correo] [teléfono] [número] en las dos formas; el número de tienda sí va',
     !prohibidos.some((x) => todo1.includes(x)) && /\[correo\].*\[teléfono\].*\[número\]/.test(zelleMsg?.descripcion ?? '')
     && zelleMsg?.desc_norm === 'ZELLE PAYMENT TO JUAN PEREZ [correo] [teléfono] ACCT [número]' && dellMsg?.desc_norm === 'DELL MARKETING L P [teléfono] TX'
     && msgs.some((m) => m?.desc_norm === 'THE HOME DEPOT 6341 OCALA FL'), { zelle: zelleMsg, dell: dellMsg, prohibidos: prohibidos.filter((x) => todo1.includes(x)) });
  const ok200 = pet1.filter((p) => p.respuesta.estado === 200);
  ok('E2E-37 el caché: la primera petición lo CREA (cache_creation > 0, sin lectura) y todas las demás que contestaron lo LEEN (cache_read > 0, sin crear)',
     pet1[0]?.respuesta?.usage?.cache_creation_input_tokens > 0 && pet1[0].respuesta.usage.cache_read_input_tokens === 0
     && ok200.slice(1).every((p) => p.respuesta.usage.cache_read_input_tokens > 0 && p.respuesta.usage.cache_creation_input_tokens === 0) && est1.creaciones === 1 && est1.lecturas === ok200.length - 1,
     pet1.map((p) => [p.respuesta.estado, p.respuesta.usage?.cache_creation_input_tokens, p.respuesta.usage?.cache_read_input_tokens]));
  const uso1 = usoSim(pet1);
  ok('E2E-38 el uso de la ráfaga es la suma de lo que contestó Anthropic (también la negativa y el corte), y cache {creacion, lectura} lo repite',
     isDeepStrictEqual(P1.usage, uso1) && P1.cache?.creacion === uso1.cache_creacion && P1.cache?.lectura === uso1.cache_lectura && uso1.cache_creacion > 0 && uso1.cache_lectura > 0, [P1.usage, uso1]);
  ok('E2E-39 los centavos: round((entrada×400 + caché creado×500 + caché leído×20 + salida×2000) / 1 000 000), los de claude-opus-5-5',
     P1.centavos === centavosDe(uso1) && P1.centavos > 0, [P1.centavos, centavosDe(uso1), uso1]);
  const det = (clave) => (P1.detalle ?? []).find((x) => x.movimiento_id === M[clave]);
  const pHd = propDe(M.hd), pWawa = propDe(M.wawa), pIrs = propDe(M.irs), pAlly = propDe(M.ally), pDell = propDe(M.dell), pAmz = propDe(M.amz), pZelle = propDe(M.zelle);
  ok('E2E-40 HOME DEPOT → pendiente de la IA: 5100, confianza 0.92, y el detalle lo dice; la obra no la adivina por la descripción: la trae de las pistas (E2E-112)',
     pHd?.estado === 'pendiente' && pHd.fuente === 'ia' && pHd.propuesta.lineas?.length === 1 && pHd.propuesta.lineas[0].cuenta === '5100' && pHd.propuesta.confianza === 0.92
     && det('hd')?.estado === 'pendiente' && det('hd').propuesta === pHd.id && typeof pHd.propuesta.motivo === 'string' && pHd.propuesta.motivo.length > 10, [pHd?.propuesta, det('hd')]);
  ok('E2E-41 WAWA → 6300 (combustible, 0.9); IRS → 3200 con el flag irs (la regla fija de la S-corp, 0.95)',
     pWawa?.estado === 'pendiente' && pWawa.propuesta.lineas[0].cuenta === '6300' && pWawa.propuesta.confianza === 0.9 && isDeepStrictEqual(pWawa.propuesta.flags, {})
     && pIrs?.estado === 'pendiente' && pIrs.propuesta.lineas[0].cuenta === '3200' && pIrs.propuesta.flags?.irs === true, [pWawa?.propuesta, pIrs?.propuesta]);
  ok('E2E-42 ALLY → dos líneas (2520 capital + 7100 intereses) con montos que suman el cargo al centavo (412.33)',
     pAlly?.estado === 'pendiente' && pAlly.propuesta.lineas.length === 2 && pAlly.propuesta.lineas.map((l) => l.cuenta).join('+') === '2520+7100'
     && Math.round(pAlly.propuesta.lineas.reduce((s, l) => s + Number(l.monto), 0) * 100) === 41233, pAlly?.propuesta);
  ok('E2E-43 DELL de 3,150.00 → 1530 con el flag capitalizable; AMAZON → 6500 con use_tax y 5500 de alternativa; el Zelle a una persona → 5200 que pide obra (0.45)',
     pDell?.propuesta.lineas[0].cuenta === '1530' && pDell.propuesta.flags?.capitalizable === true && pAmz?.propuesta.lineas[0].cuenta === '6500' && pAmz.propuesta.flags?.use_tax === true
     && pAmz.propuesta.alternativas?.[0]?.cuenta === '5500' && pZelle?.propuesta.lineas[0].cuenta === '5200' && pZelle.propuesta.flags?.pide_obra === true && pZelle.propuesta.confianza === 0.45,
     [pDell?.propuesta, pAmz?.propuesta, pZelle?.propuesta]);
  const caidas = pet1.filter((p) => /CAIDO/.test(contenido(p)));
  ok('E2E-44 el 529 (Anthropic saturado) se reintenta UNA vez tras 2 s: dos peticiones iguales, la primera 529 y la segunda 200, y la propuesta entra (intentos: 2)',
     caidas.length === 2 && caidas[0].respuesta.estado === 529 && caidas[1].respuesta.estado === 200 && caidas[1].llegada_ms - caidas[0].terminada_ms >= 1900
     && det('amz')?.intentos === 2 && det('amz').estado === 'pendiente' && pAmz?.estado === 'pendiente', [caidas.map((p) => [p.respuesta.estado, p.llegada_ms, p.terminada_ms]), det('amz')]);
  const pNfx = propDe(M.nfx), pMax = propDe(M.max), pRoto = propDe(M.roto), pInv = propDe(M.inv);
  ok('E2E-45 la NEGATIVA (stop_reason refusal) → sin respuesta: no se guarda, lo dice en llano («no se cambia de modelo») y no hay otra petición ni otro modelo',
     det('nfx')?.estado === 'sin_respuesta' && /refusal/.test(det('nfx').motivo) && /no se cambia de modelo/.test(det('nfx').motivo) && pNfx === null
     && pet1.filter((p) => /REFUSAL/.test(contenido(p))).length === 1 && pet1.every((p) => p.cuerpo.model === 'claude-opus-5-5'), det('nfx'));
  ok('E2E-46 el corte (stop_reason max_tokens) → sin respuesta «se cortó (max_tokens 4096)»: no se guarda', det('max')?.estado === 'sin_respuesta' && /max_tokens 4096/.test(det('max').motivo) && pMax === null, det('max'));
  ok('E2E-47 un JSON roto → inválida «la IA no devolvió un JSON»; una cuenta inventada (9999) → inválida, la base dice por qué (MX004): ninguna de las dos se guarda',
     det('roto')?.estado === 'invalida' && /no devolvió un JSON/.test(det('roto').motivo) && pRoto === null
     && det('inv')?.estado === 'invalida' && /9999/.test(det('inv').motivo) && det('inv').codigo === 'MX004' && pInv === null, [det('roto'), det('inv')]);
  const delLote = Number(q(`select count(*) from contador_propuestas where lote_id = ${lit(LOTE1)} and estado = 'pendiente' and fuente = 'ia'`));
  ok('E2E-48 los conteos: propuestas = las pendientes de la IA de este lote; sin respuesta = 2 (refusal, max_tokens); inválidas = 2 (JSON roto, 9999)',
     P1.propuestas === delLote && P1.propuestas === iaCands.length - 4 && P1.sin_respuesta === 2 && P1.invalidas === 2 && (P1.detalle ?? []).length === iaCands.length, { propuestas: P1.propuestas, delLote, sin: P1.sin_respuesta, inv: P1.invalidas });
  const obrasEsperadas = OBRAS.map(([id, nombre]) => ({ id, nombre }));
  const propsLote = qj(`select json_agg(json_build_object('mov', movimiento_id, 'entrada', entrada, 'salida', salida, 'modelo', modelo, 'effort', effort, 'pv', prompt_version, 'lote', lote_id))::text from contador_propuestas where lote_id = ${lit(LOTE1)}`) ?? [];
  const msgDeMov = (mov) => msgDe(pet1.filter((p) => claveMsg(p) === claveDeMov[mov] && p.respuesta.estado === 200).pop() ?? {});
  ok('E2E-49 la ENTRADA congelada de cada propuesta: el movimiento tal cual se le dio a la IA, las obras activas, y la versión de las reglas, el prefijo_hash y el prompt_version ENTEROS (la máscara no toca el sello)',
     propsLote.length === P1.propuestas && propsLote.every((x) => mismoConjunto(Object.keys(x.entrada), ['movimiento', 'obras', 'reglas_version', 'prefijo_hash', 'prompt_version'])
       && isDeepStrictEqual(x.entrada.movimiento, msgDeMov(x.mov)) && isDeepStrictEqual(x.entrada.obras, obrasEsperadas)
       && x.entrada.reglas_version === ctx1.reglas_version && x.entrada.prefijo_hash === P1.prefijo_hash && x.entrada.prompt_version === PV),
     propsLote.slice(0, 1).map((x) => ({ entrada: x.entrada, enviado: msgDeMov(x.mov) })));
  ok('E2E-50 la SALIDA cruda (la respuesta de Anthropic tal cual: id, stop_reason, el bloque thinking delante, el texto y el uso) y modelo/effort/prompt_version íntegros en sus columnas',
     propsLote.every((x) => /^msg_SIM/.test(x.salida?.id ?? '') && x.salida.stop_reason === 'end_turn' && x.salida.content?.[0]?.type === 'thinking' && x.salida.content?.[1]?.type === 'text'
       && typeof x.salida.usage?.input_tokens === 'number' && x.modelo === 'claude-opus-5-5' && x.effort === 'low' && x.pv === PV && x.lote === P1.lote), propsLote[0]?.salida);
  const lote1 = qj(`select row_to_json(l)::text from contador_lotes l where id = ${lit(LOTE1)}`);
  ok('E2E-51 el lote: cerrado, n = los movimientos, el uso y los centavos de la ráfaga, sin error, opus 5.5 / low, la versión del prompt, el hash del prefijo y quién',
     lote1?.cerrado_el && lote1.n === iaCands.length && isDeepStrictEqual(lote1.usage, uso1) && lote1.centavos === P1.centavos && lote1.error === null && lote1.modelo === 'claude-opus-5-5'
     && lote1.effort === 'low' && lote1.prompt_version === PV && lote1.prefijo_hash === P1.prefijo_hash && lote1.por === dueno && lote1.accion === 'categorizar', lote1);
  const gasto1 = gastoContador();
  ok('E2E-52 el gasto del mes sube (asistente_costo_mes, acción contador_categorizar): los centavos del lote y una llamada más; el tope lo ve',
     gasto1[0] - gasto0[0] === P1.centavos && gasto1[1] - gasto0[1] === 1 && Number(P1.tope?.centavos_mes_contador) === gasto1[0], { gasto0, gasto1, tope: P1.tope });
  ok('E2E-53 contador_config guarda la ráfaga: ultima_rafaga_el de ahora, el prompt_version y el prefijo_hash, sin error',
     q(`select (ultima_rafaga_el > now() - interval '5 minutes') || '|' || prompt_version || '|' || prefijo_hash || '|' || coalesce(ultimo_error, '-') from contador_config`) === `true|${PV}|${P1.prefijo_hash}|-`);
  const est53 = qj(`select row_to_json(e)::text from v_contador_estado e`);
  const band = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M.hd)}`);
  const bandZ = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M.zelle)}`);
  ok('E2E-54 v_contador_estado y v_contador_bandeja: las pendientes (de la IA y de la regla), y por movimiento la propuesta con la cuenta y la obra resueltas, la confianza, los flags y el modelo (el HOME DEPOT con la obra que propuso; el Zelle, que pide obra); la alarma 73 en verde',
     Number(est53?.propuestas_pendientes) === P1.propuestas + casanNfpa && Number(est53.propuestas_por_ia) === P1.propuestas && Number(est53.propuestas_por_regla) === casanNfpa
     && band?.propuesta_id === pHd.id && band.estado === 'pendiente' && band.fuente === 'ia' && band.lineas?.[0]?.cuenta === '5100' && band.lineas[0].cuenta_nombre
     && band.lineas[0].proyecto_id === OBRA3 && band.lineas[0].obra === OBRA3_NOMBRE && band.lineas[0].pide_obra === false && band.pide_obra === false
     && Number(band.confianza) === 0.92 && band.modelo === 'claude-opus-5-5'
     && bandZ?.propuesta_id === pZelle.id && bandZ.lineas?.[0]?.cuenta === '5200' && bandZ.lineas[0].pide_obra === true && bandZ.pide_obra === true
     && !rojos('alarma').some((x) => /^73 /.test(x)), { est53, band, bandZ });
  ok('E2E-55 PROPONE, NUNCA POSTEA: la ráfaga no tocó el libro (ningún asiento nuevo) y cada cargo sigue pendiente en la bandeja',
     q(`select count(*) from asientos`) === asientos0 && sembrados.every((m) => estadoMov(m) === 'pendiente|-'), q(`select count(*) from asientos`) + ' vs ' + asientos0);

  // ---- E2E-110 LA OBRA (7b) en la primera ráfaga: las pistas viajan, nada personal, la IA propone, la base la deja ------
  // (numeradas desde la 110: las de antes no se renumeran)
  const CLAVES_OBRA = ['proyecto_id', 'nombre', 'horas_cerca', 'horas_mes', 'recibos_proveedor', 'veces_elegida', 'materiales_recientes'];
  const idsObras = new Set(OBRAS.map(([id]) => id));
  // la forma del contrato de pistas_obra: {obras: hasta 6, de obras activas, con sus cinco totales y sin «puntos»;
  // candidata {proyecto_id, nombre, confianza (0..0,9), motivo} —la primera obra— o null; resumen («sin pistas» sin obras)}
  const formaPistas = (po) => !!po && typeof po === 'object' && !Array.isArray(po) && mismoConjunto(Object.keys(po), ['obras', 'candidata', 'resumen'])
    && Array.isArray(po.obras) && po.obras.length <= 6 && typeof po.resumen === 'string' && (po.obras.length > 0 || po.resumen === 'sin pistas')
    && po.obras.every((o) => !!o && mismoConjunto(Object.keys(o), CLAVES_OBRA) && idsObras.has(o.proyecto_id) && typeof o.nombre === 'string'
      && CLAVES_OBRA.slice(2).every((k) => typeof o[k] === 'number' && o[k] >= 0))
    && (po.candidata === null || (!!po.candidata && mismoConjunto(Object.keys(po.candidata), ['proyecto_id', 'nombre', 'confianza', 'motivo'])
      && po.candidata.proyecto_id === po.obras[0]?.proyecto_id && po.candidata.confianza > 0 && po.candidata.confianza <= 0.9
      && typeof po.candidata.motivo === 'string' && po.candidata.motivo.length > 10));
  // (contador_propuestas.pistas guarda lo que vio la base, con los puntos de cada obra; a la IA va sin ellos)
  const sinPuntos = (p) => p && typeof p === 'object' ? { ...p, obras: (p.obras ?? []).map(({ puntos: _puntos, ...o }) => o) } : p;
  const obraP = (po, id) => (po?.obras ?? []).find((o) => o.proyecto_id === id);
  const escRe = (t) => String(t ?? '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const msgHd = msgDeMov(M.hd), msgZelle = msgDeMov(M.zelle);
  const MOTIVO_HD = `la cuadrilla reportó 24 h en ${OBRA3_NOMBRE} esos días`;
  ok('E2E-110 (7b) LAS PISTAS VIAJAN: cada petición a la IA trae pistas_obra con la forma del contrato (obras activas con sus cinco totales, sin «puntos»; la candidata o null; el resumen) y son las que vio la base (contador_propuestas.pistas sin los puntos): el HOME DEPOT con las 24 h de OBRA3 esos días y su candidata («la cuadrilla reportó 24 h en … esos días»); el Zelle con esas 24 h solo en el mes y sin candidata',
     pet1.length > 0 && pet1.every((p) => p.pistas_obra === true && formaPistas(msgDe(p)?.pistas_obra))
     && isDeepStrictEqual(msgHd?.pistas_obra, sinPuntos(pHd?.pistas)) && msgHd.pistas_obra.candidata?.proyecto_id === OBRA3 && msgHd.pistas_obra.candidata.motivo === MOTIVO_HD
     && obraP(msgHd.pistas_obra, OBRA3)?.horas_cerca === 24 && obraP(msgHd.pistas_obra, OBRA3)?.horas_mes === 24
     && isDeepStrictEqual(msgZelle?.pistas_obra, sinPuntos(pZelle?.pistas)) && msgZelle.pistas_obra.candidata === null
     && obraP(msgZelle.pistas_obra, OBRA3)?.horas_cerca === 0 && obraP(msgZelle.pistas_obra, OBRA3)?.horas_mes === 24,
     { hd: msgHd?.pistas_obra, guardadas: pHd?.pistas, zelle: msgZelle?.pistas_obra,
       malas: pet1.filter((p) => p.pistas_obra !== true || !formaPistas(msgDe(p)?.pistas_obra)).slice(0, 2).map((p) => msgDe(p)?.pistas_obra ?? contenido(p).slice(0, 200)) });
  // (lo personal que la base sabe de esas horas y de esos tickets: quién —su uuid, su nombre—, su nota, la foto)
  const perfilesIds = q(`select coalesce(string_agg(id::text, ' '), '') from perfiles`).split(' ').filter(Boolean);
  const nombresEquipo = q(`select coalesce(string_agg(nombre, '|'), '') from perfiles where rol <> 'dueno'`).split('|').filter((x) => x.length >= 3);
  const textoMensajes = (ps) => ps.map((p) => contenido(p)).join('\n');
  const personal = (txt) => [...perfilesIds, ...nombresEquipo, NOTA_SECRETA, 'SECRETA', 'usuario_id', 'autor_id', '"notas"', '"ruta"', 'recibos/'].filter((x) => txt.includes(x));
  ok('E2E-111 (7b) NADA PERSONAL en las pistas: ningún mensaje a la IA lleva un usuario_id ni un autor_id, el id de nadie de perfiles, el nombre de alguien del equipo, la nota de las horas ni la ruta de una foto: solo totales por obra y el nombre de la obra',
     perfilesIds.length >= 2 && nombresEquipo.length >= 1 && personal(textoMensajes(pet1)).length === 0, personal(textoMensajes(pet1)));
  const anotHd = pet1.filter((p) => claveMsg(p) === claveDeMov[M.hd]).pop();
  ok('E2E-112 (7b) LA IA PROPONE LA OBRA y la base la deja: el HOME DEPOT queda con la línea 5100 en OBRA3 (el proyecto_id en la línea), sin pide_obra, con flags.obra_propuesta, propuesta.obra {OBRA3, 0.8, el motivo de la pista} y sin nota; el detalle dice su obra; la entrada congela las pistas que viajaron y «pistas», las de la base con sus puntos',
     isDeepStrictEqual(pHd?.propuesta?.lineas, [{ cuenta: '5100', proyecto_id: OBRA3 }]) && isDeepStrictEqual(pHd.propuesta.flags, { obra_propuesta: true })
     && isDeepStrictEqual(pHd.propuesta.obra, { proyecto_id: OBRA3, confianza: 0.8, motivo: MOTIVO_HD }) && pHd.nota === null
     && det('hd')?.obra === OBRA3 && det('hd').pide_obra === false && det('hd').obra_nota === undefined && anotHd?.candidata === OBRA3 && anotHd.obra === OBRA3
     && isDeepStrictEqual(pHd.entrada?.movimiento?.pistas_obra, msgHd?.pistas_obra) && pHd.pistas?.candidata?.proyecto_id === OBRA3 && typeof pHd.pistas?.obras?.[0]?.puntos === 'number',
     { propuesta: pHd?.propuesta, nota: pHd?.nota, det: det('hd'), anot: [anotHd?.candidata, anotHd?.obra] });
  const conObraPend = Number(q(`select count(*) from contador_propuestas where estado = 'pendiente' and jsonb_typeof(propuesta->'obra') = 'object'`));
  ok('E2E-113 (7b) v_contador_bandeja enseña la obra propuesta del HOME DEPOT (obra_propuesta_id, su nombre, obra_confianza 0.8, obra_motivo) y el resumen de sus pistas; el Zelle, sin obra propuesta y con sus pistas a la vista (OBRA3: 24 h en 30 días); v_contador_estado cuenta las pendientes con obra',
     band?.obra_propuesta_id === OBRA3 && band.obra_propuesta === OBRA3_NOMBRE && Number(band.obra_confianza) === 0.8 && band.obra_motivo === MOTIVO_HD
     && band.pistas_resumen === pHd.pistas?.resumen && band.pistas_resumen.startsWith(`${OBRA3_NOMBRE}: 24 h esos días`)
     && bandZ?.obra_propuesta_id === null && bandZ.obra_propuesta === null && bandZ.obra_confianza === null && bandZ.obra_motivo === null
     && bandZ.pistas_resumen === pZelle.pistas?.resumen && bandZ.pistas_resumen.includes(`${OBRA3_NOMBRE}: 24 h en 30 días`)
     && conObraPend >= 1 && Number(est53?.propuestas_con_obra) === conObraPend, { band, bandZ, conObraPend, est: est53?.propuestas_con_obra });
  const detObra = (P1.detalle ?? []).filter((d) => d.obra);
  const candDe = (mov) => msgDeMov(mov)?.pistas_obra?.candidata?.proyecto_id ?? null;
  const conObraLote1 = Number(q(`select count(*) from contador_propuestas where lote_id = ${lit(LOTE1)} and estado = 'pendiente' and jsonb_typeof(propuesta->'obra') = 'object'`));
  ok('E2E-114 (7b) con_obra en la respuesta = las del detalle con obra = las pendientes de la IA del lote con obra, y cada obra es la candidata de sus pistas (la IA no inventó ninguna); sin pistas que alcancen (el Zelle) o en una cuenta sin obra (el WAWA), obra null',
     typeof P1.con_obra === 'number' && P1.con_obra >= 1 && P1.con_obra === detObra.length && P1.con_obra === conObraLote1 && detObra.some((d) => d.movimiento_id === M.hd)
     && detObra.every((d) => d.obra === candDe(d.movimiento_id)) && det('zelle')?.obra === undefined && det('zelle').pide_obra === true && det('wawa')?.obra === undefined,
     { con_obra: P1.con_obra, detalle: detObra.length, lote: conObraLote1, otras: detObra.filter((d) => d.obra !== candDe(d.movimiento_id)) });

  // ---- E2E-56 la segunda ráfaga: mismo prefijo, todo del caché ----------------------------------------
  let antes = await llamadasSim();
  r = await proponer();
  let pet = await peticiones(antes);
  ok('E2E-56 la segunda ráfaga: solo vuelven los que no quedaron (refusal, max_tokens, JSON roto, 9999), y otra vez sin guardar nada',
     r.estado === 200 && r.j.movimientos === 4 && r.j.propuestas === 0 && r.j.sin_respuesta === 2 && r.j.invalidas === 2 && r.j.reglas === 0 && pet.length === 4
     && mismoConjunto(pet.map(claveMsg), [M.nfx, M.max, M.roto, M.inv].map((m) => claveDeMov[m])), { ...r.j, detalle: undefined });
  ok('E2E-57 …con el MISMO prefijo (nada cambió en el contexto): el mismo prefijo_hash y todas leen el caché, ninguna lo crea',
     r.j.prefijo_hash === P1.prefijo_hash && pet.every((p) => p.respuesta.usage?.cache_read_input_tokens > 0 && p.respuesta.usage.cache_creation_input_tokens === 0) && r.j.cache?.creacion === 0,
     pet.map((p) => p.respuesta.usage));

  // ---- E2E-58 los reintentos: 429, 5xx dos veces, el límite --------------------------------------------
  const M2 = sembrar([{ clave: 'publix', desc: 'PUBLIX SUPER MARKET 1520', monto: 64.18, dias: 9 }]);
  await sim('/__caer', { veces: 1, estado: 429 });
  antes = await llamadasSim();
  r = await proponer({ limite: 1 });
  pet = await peticiones(antes);
  ok('E2E-58 un 429 (límite de velocidad) se reintenta una vez tras 2 s y la propuesta entra (PUBLIX → 3200 personal, intentos 2); limite 1 = un movimiento, el más viejo',
     r.estado === 200 && r.j.movimientos === 1 && r.j.total === 5 && pet.length === 2 && pet[0].respuesta.estado === 429 && pet[1].respuesta.estado === 200 && pet[1].llegada_ms - pet[0].terminada_ms >= 1900
     && r.j.detalle?.[0]?.movimiento_id === M2.publix && r.j.detalle[0].intentos === 2 && propDe(M2.publix)?.propuesta?.flags?.personal === true, { ...r.j, pet: pet.map((p) => p.respuesta.estado) });
  await sim('/__caer', { veces: 2, estado: 500 });
  antes = await llamadasSim();
  const propsAntes = q(`select count(*) from contador_propuestas`);
  r = await proponer({ limite: 1 });
  pet = await peticiones(antes);
  ok('E2E-59 un 500 dos veces → sin respuesta «Anthropic no contestó (HTTP 500, dos veces)»: exactamente dos peticiones, nada guardado, el lote cerrado (0 centavos)',
     r.estado === 200 && r.j.movimientos === 1 && r.j.sin_respuesta === 1 && /HTTP 500, dos veces/.test(r.j.detalle?.[0]?.motivo ?? '') && r.j.detalle[0].intentos === 2 && pet.length === 2
     && pet.every((p) => p.respuesta.estado === 500) && claveMsg(pet[0]) === claveMsg(pet[1]) && q(`select count(*) from contador_propuestas`) === propsAntes && r.j.centavos === 0
     && q(`select (cerrado_el is not null) || '|' || centavos from contador_lotes where id = ${lit(r.j.lote)}`) === 'true|0', { ...r.j, pet: pet.map((p) => p.respuesta.estado) });
  q(`update contador_config set max_por_rafaga = 2 where id = 1`);
  antes = await llamadasSim();
  r = await proponer({ limite: 50 });
  q(`update contador_config set max_por_rafaga = 20 where id = 1`);
  ok('E2E-60 el límite nunca pasa de max_por_rafaga (2 aquí, aunque se pidan 50)', r.estado === 200 && r.j.movimientos === 2 && (await llamadasSim()) - antes === 2, { ...r.j, detalle: undefined });

  // ---- E2E-61 aprobar («Así es») --------------------------------------------------------------------
  const asientosAntes = Number(q(`select count(*) from asientos`));
  // (desde la 7b el HOME DEPOT trae su obra propuesta: «elige la obra» se prueba con el Zelle, cuyas pistas no alcanzan)
  r = await llamar({ accion: 'aprobar', propuesta: pZelle.id }, { jwt: D2 });
  ok('E2E-61 aprobar el Zelle (5200, que pide obra y sin obra propuesta: sus pistas no alcanzan) sin elegir la obra → 409 MX008 con la pista «elige la obra» (dice 5200), y nada entra al libro',
     r.estado === 409 && r.j.codigo === 'MX008' && r.j.pista === 'elige la obra' && /5200/.test(r.j.error) && propDe(M.zelle).estado === 'pendiente' && estadoMov(M.zelle) === 'pendiente|-'
     && Number(q(`select count(*) from asientos`)) === asientosAntes, r);
  r = await llamar({ accion: 'aprobar', propuesta: pHd.id, proyecto_id: 'no-existe-x' }, { jwt: D2 });
  const r62 = await llamar({ accion: 'aprobar', propuesta: 'no-es-un-uuid' }, { jwt: D2 });
  ok('E2E-62 aprobar con una obra que no existe → 409 22023; con una propuesta que no es un uuid → 400 FORMA', r.estado === 409 && r.j.codigo === '22023' && /no existe/.test(r.j.error) && r62.estado === 400 && r62.j.codigo === 'FORMA', [r, r62]);
  // (Edgar elige OBRA2, la obra del ticket de Home Depot de la semilla, y no la OBRA3 que propuso la IA: así el siguiente
  // HOME DEPOT trae candidata OBRA2 sea cual sea el día —E2E-116—)
  r = await llamar({ accion: 'aprobar', propuesta: pHd.id, proyecto_id: OBRA2 }, { jwt: D2 });
  const aHd = propDe(M.hd);
  ok('E2E-63 aprobar HOME DEPOT con OTRA obra (OBRA2; la IA propuso OBRA3) → 200 «editada»: la obra de Edgar manda; con su asiento; la propuesta guarda quién, cuándo, las líneas finales (con la obra de Edgar) y el asiento del movimiento',
     r.estado === 200 && r.j.ok && r.j.estado === 'editada' && r.j.fuente === 'ia' && r.j.propuesta === pHd.id && r.j.movimiento === M.hd && RE_UUID.test(r.j.asiento_id ?? '')
     && isDeepStrictEqual(r.j.lineas, [{ cuenta: '5100', proyecto_id: OBRA2 }]) && aHd.estado === 'editada' && aHd.aprobado_por === dueno && aHd.aprobado_el
     && isDeepStrictEqual(aHd.lineas_finales, [{ cuenta: '5100', proyecto_id: OBRA2 }]) && aHd.asiento_id === r.j.asiento_id && estadoMov(M.hd) === `casado|${r.j.asiento_id}`, [r.j, aHd]);
  const asHd = qj(`select row_to_json(a)::text from (select origen_tabla, camino, usuario_id, descripcion, reversa_a from asientos where id = ${lit(r.j.asiento_id)}) a`);
  ok('E2E-64 el asiento es el de c6 (fn_banco_clasificar, origen movimientos_banco) en nombre del dueño, vivo: 5100 +87.43 con la obra de Edgar y 1010 −87.43, y dice «Propuesta de la IA #<id> editada por Edgar: …»',
     asHd?.origen_tabla === 'movimientos_banco' && asHd.usuario_id === dueno && asHd.reversa_a === null && asientoVivo(r.j.asiento_id)
     && lineasDe(r.j.asiento_id) === `1010 -87.43 | 5100 87.43 @${OBRA2}` && new RegExp(`^Propuesta de la IA #${pHd.id} editada por Edgar: `).test(asHd.descripcion), [asHd, lineasDe(r.j.asiento_id)]);
  const rgHd = qj(`select row_to_json(x)::text from (select id, nombre, patron, lineas, pide_obra, origen, activa, creada_por from contador_reglas where nombre = 'THE HOME DEPOT') x`);
  ok('E2E-65 «Recordar» (por defecto): nace la regla del comercio «THE HOME DEPOT» (^THE HOME DEPOT), origen aprobacion, con la cuenta y SIN la obra (v1), pide obra',
     r.j.regla?.nueva === true && r.j.regla.nombre === 'THE HOME DEPOT' && rgHd?.patron === '^THE HOME DEPOT' && rgHd.origen === 'aprobacion' && rgHd.activa === true && rgHd.creada_por === dueno
     && isDeepStrictEqual(rgHd.lineas, [{ cuenta: '5100' }]) && rgHd.pide_obra === true, [r.j.regla, rgHd]);
  const bHdE = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M.hd)}`);
  ok('E2E-115 (7b) LA OBRA DE EDGAR MANDA y el rastro queda: la propuesta sigue diciendo lo que propuso la IA (propuesta.obra y la línea con OBRA3) y lo que entró es lo de Edgar (lineas_finales y el asiento con OBRA2); la bandeja enseña las dos; la regla aprendida no guarda ninguna',
     isDeepStrictEqual(aHd.propuesta?.obra, { proyecto_id: OBRA3, confianza: 0.8, motivo: MOTIVO_HD }) && isDeepStrictEqual(aHd.propuesta.lineas, [{ cuenta: '5100', proyecto_id: OBRA3 }])
     && bHdE?.estado === 'editada' && bHdE.obra_propuesta_id === OBRA3 && isDeepStrictEqual(bHdE.lineas_finales, [{ cuenta: '5100', proyecto_id: OBRA2 }]) && bHdE.asiento_vivo === true
     && !JSON.stringify(rgHd?.lineas ?? null).includes('proyecto_id'), [aHd?.propuesta, bHdE, rgHd]);
  r = await llamar({ accion: 'aprobar', propuesta: pHd.id, proyecto_id: OBRA }, { jwt: D2 });
  ok('E2E-66 aprobar otra vez la misma → 409 MX008 «no se aprueba dos veces»', r.estado === 409 && r.j.codigo === 'MX008' && /dos veces/.test(r.j.error), r);
  r = await llamar({ accion: 'aprobar', propuesta: pWawa.id }, { jwt: D2 });
  const r67 = await llamar({ accion: 'aprobar', propuesta: pAlly.id }, { jwt: D2 });
  const rgAlly = qj(`select row_to_json(x)::text from (select lineas from contador_reglas where id = ${lit(r67.j?.regla?.regla)}) x`);
  ok('E2E-67 aprobar WAWA → regla ^WAWA (sin obra); aprobar ALLY (dos líneas) → su asiento con 2520 y 7100, y la regla guarda las partes (suman 1)',
     r.estado === 200 && r.j.estado === 'aprobada' && q(`select patron || '|' || pide_obra from contador_reglas where nombre = 'WAWA' and activa`) === '^WAWA|false'
     && r67.estado === 200 && r67.j.estado === 'aprobada' && lineasDe(r67.j.asiento_id) === `1010 -412.33 | 2520 ${pAlly.propuesta.lineas[0].monto} | 7100 ${pAlly.propuesta.lineas[1].monto}`
     && rgAlly?.lineas?.length === 2 && Math.abs(rgAlly.lineas.reduce((s, l) => s + Number(l.parte), 0) - 1) < 1e-9, [r.j, r67.j, rgAlly, lineasDe(r67.j?.asiento_id)]);
  r = await llamar({ accion: 'aprobar', propuesta: pZelle.id, proyecto_id: OBRA2, recordar: false }, { jwt: D2 });
  ok('E2E-68 aprobar el Zelle (5200, pide obra) con la otra obra y recordar:false → aprobada con esa obra y SIN regla',
     r.estado === 200 && r.j.estado === 'aprobada' && r.j.regla === undefined && lineasDe(r.j.asiento_id) === `1010 -600.00 | 5200 600.00 @${OBRA2}`
     && q(`select count(*) from contador_reglas where patron like '^ZELLE%'`) === '0', r.j);

  // ---- E2E-69 el siguiente del mismo comercio sale por regla, sin IA --------------------------------------
  const M3 = sembrar([
    { clave: 'wawa2', desc: 'WAWA 5300 OCALA FL', monto: 41.00, dias: 1 },
    { clave: 'hd2', desc: 'THE HOME DEPOT 0221 GAINESVILLE FL', monto: 230.15, dias: 1 },
    { clave: 'wawa3', desc: 'WAWA 6001 SUMMERFIELD FL', monto: 33.33, dias: 1 },
  ]);
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  const pW2 = propDe(M3.wawa2), pH2 = propDe(M3.hd2), pW3 = propDe(M3.wawa3);
  const R69 = r.j ?? {};
  ok('E2E-69 el siguiente WAWA y el siguiente HOME DEPOT salen por REGLA (confianza 1, «Regla: …»; el de Home Depot con la obra de sus pistas: E2E-116) y la IA no los ve',
     r.estado === 200 && r.j.reglas === 3 && pW2?.fuente === 'regla' && pW2.propuesta.motivo === 'Regla: WAWA' && pW2.propuesta.lineas[0].cuenta === '6300' && pW3?.fuente === 'regla'
     && pH2?.fuente === 'regla' && pH2.propuesta.motivo === 'Regla: THE HOME DEPOT' && pH2.propuesta.lineas?.[0]?.cuenta === '5100' && pH2.propuesta.confianza === 1
     && !pet.some((p) => /WAWA|HOME DEPOT/.test(contenido(p))) && pet.length === r.j.movimientos, { ...r.j, detalle: undefined });
  const prefijo2 = pet[0]?.cuerpo?.system?.[0]?.text ?? '';
  ok('E2E-70 el prefijo cambió con lo aprendido: trae las reglas nuevas y los ejemplos de Edgar (lo aprobado, con su obra), sigue sin fechas ni uuids, y la primera petición crea su caché',
     r.j.prefijo_hash !== P1.prefijo_hash && sha256(prefijo2) === r.j.prefijo_hash && /\nTHE HOME DEPOT: 5100 \(patrón \^THE HOME DEPOT, pide obra\)/.test(prefijo2) && /\nWAWA: 6300 \(patrón \^WAWA\)/.test(prefijo2)
     && prefijo2.includes(`«THE HOME DEPOT 6341 OCALA FL» → 5100 · obra ${OBRA2}`) && prefijo2.includes('«WAWA 5213 TAMPA FL» → 6300') && !pet[0]?.prefijo?.tiene_fecha && !pet[0]?.prefijo?.tiene_uuid
     && pet[0]?.respuesta?.usage?.cache_creation_input_tokens > 0 && pet.slice(1).every((p) => p.respuesta.estado !== 200 || p.respuesta.usage.cache_read_input_tokens > 0),
     prefijo2.slice(prefijo2.lastIndexOf('REGLAS DE EDGAR'), prefijo2.lastIndexOf('REGLAS DE EDGAR') + 700));
  const candH2 = pH2?.pistas?.candidata;
  const bH2 = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M3.hd2)}`);
  ok('E2E-116 (7b) REGLA + CANDIDATA (la regla dice la cuenta; las pistas, la obra): el siguiente HOME DEPOT sale por regla con la línea 5100 en OBRA2 —Edgar la eligió la última vez con THE HOME DEPOT, y el ticket de Home Depot de la semilla—, flags.obra_propuesta y sin pide_obra, propuesta.obra con la confianza y el motivo de la candidata, el resumen de las pistas en la entrada y en la bandeja; con_obra de la respuesta cuenta solo lo de la IA',
     candH2?.proyecto_id === OBRA2 && isDeepStrictEqual(pH2.propuesta.lineas, [{ cuenta: '5100', proyecto_id: OBRA2 }]) && isDeepStrictEqual(pH2.propuesta.flags, { obra_propuesta: true })
     && isDeepStrictEqual(pH2.propuesta.obra, { proyecto_id: OBRA2, confianza: candH2.confianza, motivo: candH2.motivo }) && obraP(pH2.pistas, OBRA2)?.veces_elegida === 1
     && new RegExp(`Edgar eligió (esa obra|${escRe(OBRA2_NOMBRE)}) la última vez con THE HOME DEPOT`).test(candH2.motivo)
     && pH2.entrada?.pistas_resumen === pH2.pistas.resumen && bH2?.obra_propuesta_id === OBRA2 && Number(bH2.obra_confianza) === candH2.confianza && bH2.obra_motivo === candH2.motivo
     && bH2.pide_obra === false && bH2.pistas_resumen === pH2.pistas.resumen && R69.con_obra === (R69.detalle ?? []).filter((d) => d.obra).length,
     { propuesta: pH2?.propuesta, pistas: pH2?.pistas, entrada: pH2?.entrada, con_obra: R69.con_obra });
  r = await llamar({ accion: 'aprobar', propuesta: pW2.id }, { jwt: D2 });
  const asW2 = q(`select descripcion from asientos where id = ${lit(r.j?.asiento_id)}`);
  ok('E2E-71 aprobar la propuesta de la regla → aprobada (la regla no cambia: nueva false), y su asiento también dice «Propuesta de la IA #<id> aprobada por Edgar: Regla: WAWA» (c6 le añade la descripción del banco)',
     r.estado === 200 && r.j.estado === 'aprobada' && r.j.fuente === 'regla' && r.j.regla?.nueva === false && r.j.regla.cambio === false
     && asW2 === `Propuesta de la IA #${pW2.id} aprobada por Edgar: Regla: WAWA: WAWA 5300 OCALA FL`, [r.j, asW2]);
  r = await llamar({ accion: 'aprobar', propuesta: pH2.id }, { jwt: D2 });
  const aH2 = propDe(M3.hd2);
  ok('E2E-72 la regla que pide obra, con la candidata de las pistas: aprobar sin elegir la obra → aprobada con la obra propuesta (la línea con su proyecto_id), su asiento, y la regla no cambia (nueva false, cambio false)',
     r.estado === 200 && r.j.estado === 'aprobada' && r.j.fuente === 'regla' && lineasDe(r.j.asiento_id) === `1010 -230.15 | 5100 230.15 @${OBRA2}`
     && isDeepStrictEqual(aH2?.lineas_finales, [{ cuenta: '5100', proyecto_id: OBRA2 }]) && r.j.regla?.nueva === false && r.j.regla.cambio === false, [r.j, aH2?.lineas_finales]);
  const rgHd2 = qj(`select row_to_json(x)::text from (select lineas, pide_obra from contador_reglas where nombre = 'THE HOME DEPOT' and activa) x`);
  const reglasConObra = q(`select count(*) from contador_reglas r cross join lateral jsonb_array_elements(r.lineas) x where r.origen = 'aprobacion' and x ? 'proyecto_id'`);
  ok('E2E-117 (7b) la regla aprendida sigue SIN la obra aunque Edgar aprobó dos veces con OBRA2 (la cuenta es del comercio; la obra, de cada compra): THE HOME DEPOT = [{cuenta 5100}] y pide obra; ninguna regla aprendida guarda una obra',
     isDeepStrictEqual(rgHd2?.lineas, [{ cuenta: '5100' }]) && rgHd2.pide_obra === true && reglasConObra === '0', [rgHd2, reglasConObra]);

  // ---- E2E-73 clasificar («Según yo») ----------------------------------------------------------
  r = await llamar({ accion: 'clasificar', movimiento: M.irs, lineas: [{ cuenta: '1130' }], motivo: 'Edgar lo devuelve a la empresa', recordar: false }, { jwt: D2 });
  const eIrs = propDe(M.irs);
  ok('E2E-73 clasificar el del IRS a otra cuenta (1130) → «editada»: el asiento con las líneas de Edgar, su motivo, y sin regla (recordar:false)',
     r.estado === 200 && r.j.estado === 'editada' && r.j.fuente === 'ia' && eIrs.estado === 'editada' && isDeepStrictEqual(eIrs.lineas_finales, [{ cuenta: '1130' }])
     && eIrs.motivo_edgar === 'Edgar lo devuelve a la empresa' && lineasDe(r.j.asiento_id) === '1010 -1200.00 | 1130 1200.00' && r.j.regla === undefined
     && new RegExp(`^Propuesta de la IA #${pIrs.id} editada por Edgar: .* · Edgar: Edgar lo devuelve a la empresa: IRS USATAXPYMT 240415$`).test(q(`select descripcion from asientos where id = ${lit(r.j.asiento_id)}`))
     && q(`select count(*) from contador_reglas where patron like '^IRS%'`) === '0', [r.j, eIrs?.estado]);
  r = await llamar({ accion: 'clasificar', movimiento: M.dell, lineas: [{ cuenta: '1530', monto: 2000 }, { cuenta: '6500', monto: 1150 }], motivo: 'La laptop es activo; el resto, accesorios' }, { jwt: D2 });
  const rgDell = qj(`select row_to_json(x)::text from (select nombre, lineas from contador_reglas where id = ${lit(r.j?.regla?.regla)}) x`);
  ok('E2E-74 clasificar DELL en DOS líneas de Edgar (1530 2,000 + 6500 1,150) → editada, el asiento con las dos, y la regla del comercio con sus partes',
     r.estado === 200 && r.j.estado === 'editada' && lineasDe(r.j.asiento_id) === '1010 -3150.00 | 1530 2000.00 | 6500 1150.00' && rgDell?.nombre === 'DELL MARKETING L P'
     && rgDell.lineas.map((l) => l.cuenta).join('+') === '1530+6500', [r.j, rgDell]);
  r = await llamar({ accion: 'clasificar', movimiento: M.nfx, lineas: [{ cuenta: '3200' }], motivo: 'Netflix de la casa de Edgar' }, { jwt: D2 });
  const eNfx = propDe(M.nfx);
  ok('E2E-75 clasificar el de Netflix (la IA no contestó: sin propuesta) → una fila «edgar» ya aprobada (el rastro es uno), su asiento y la regla del comercio',
     r.estado === 200 && r.j.fuente === 'edgar' && r.j.estado === 'aprobada' && eNfx?.fuente === 'edgar' && eNfx.estado === 'aprobada' && eNfx.asiento_id === r.j.asiento_id
     && r.j.regla?.nueva === true && /^\^NETFLIX/.test(r.j.regla.patron) && q(`select descripcion from asientos where id = ${lit(r.j.asiento_id)}`) === 'Netflix de la casa de Edgar: NETFLIX.COM REFUSAL', [r.j, eNfx?.estado]);
  const frenos = [
    ['a 5100 sin obra → 409 MX008 «elige la obra»', await llamar({ accion: 'clasificar', movimiento: M.roto, lineas: [{ cuenta: '5100' }] }, { jwt: D2 }), (x) => x.estado === 409 && x.j.codigo === 'MX008' && x.j.pista === 'elige la obra'],
    ['a 6000 (sueldos) → 409 MX004', await llamar({ accion: 'clasificar', movimiento: M.roto, lineas: [{ cuenta: '6000' }] }, { jwt: D2 }), (x) => x.estado === 409 && x.j.codigo === 'MX004'],
    ['sin líneas → 400 FORMA', await llamar({ accion: 'clasificar', movimiento: M.roto, lineas: [] }, { jwt: D2 }), (x) => x.estado === 400 && x.j.codigo === 'FORMA'],
    ['un movimiento que no es un uuid → 400 FORMA', await llamar({ accion: 'clasificar', movimiento: 'x', lineas: [{ cuenta: '6500' }] }, { jwt: D2 }), (x) => x.estado === 400 && x.j.codigo === 'FORMA'],
    ['uno que ya está casado → el error de c6 tal cual (409 MX…)', await llamar({ accion: 'clasificar', movimiento: M.hd, lineas: [{ cuenta: '6500' }] }, { jwt: D2 }), (x) => x.estado === 409 && /^MX/.test(x.j.codigo) && /casad/i.test(x.j.error)],
  ];
  ok('E2E-76 clasificar frena en llano: ' + frenos.map(([n]) => n).join('; '), frenos.every(([, x, f]) => f(x)) && estadoMov(M.roto) === 'pendiente|-',
     frenos.filter(([, x, f]) => !f(x)).map(([n, x]) => [n, x.estado, x.j]));
  r = await llamar({ accion: 'clasificar', movimiento: M.roto, lineas: [{ cuenta: '5100', proyecto_id: OBRA }], motivo: 'Material de la obra comprado en una tienda de barrio', recordar: true }, { jwt: D2 });
  const bRoto = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M.roto)}`);
  ok('E2E-77 clasificar {movimiento, lineas:[{cuenta, proyecto_id}], motivo, recordar} → la regla «ROTO STORE» sin la obra (pide obra), y la bandeja enseña la línea con el nombre de la cuenta y de la obra',
     r.estado === 200 && r.j.fuente === 'edgar' && lineasDe(r.j.asiento_id) === `1010 -22.00 | 5100 22.00 @${OBRA}` && r.j.regla?.nombre === 'ROTO STORE'
     && q(`select lineas::text || '|' || pide_obra from contador_reglas where nombre = 'ROTO STORE'`) === '[{"cuenta": "5100"}]|true'
     && bRoto?.lineas?.[0]?.obra === OBRA_NOMBRE && bRoto.lineas[0].cuenta_nombre && bRoto.asiento_vivo === true, [r.j, bRoto]);

  // ---- E2E-78 rechazar («No es eso») ---------------------------------------------------------
  r = await llamar({ accion: 'rechazar', propuesta: pAmz.id, motivo: 'Fue material para la obra, no oficina' }, { jwt: D2 });
  ok('E2E-78 rechazar AMAZON → «rechazada» con el motivo de Edgar; el cargo sigue en la bandeja (pendiente, sin asiento) y v_contador_bandeja lo enseña rechazado',
     r.estado === 200 && r.j.estado === 'rechazada' && r.j.motivo_edgar === 'Fue material para la obra, no oficina' && propDe(M.amz).estado === 'rechazada' && estadoMov(M.amz) === 'pendiente|-'
     && q(`select motivo from v_banco_bandeja where movimiento_id = ${lit(M.amz)}`) === 'sin_ticket' && q(`select estado from v_contador_bandeja where movimiento_id = ${lit(M.amz)}`) === 'rechazada', r.j);
  r = await llamar({ accion: 'rechazar', propuesta: pAmz.id }, { jwt: D2 });
  const r79 = await llamar({ accion: 'rechazar', propuesta: pW3.id }, { jwt: D2 });
  ok('E2E-79 rechazar otra vez → 409 MX008; rechazar sin motivo (la de la regla WAWA) → el de fábrica «No es eso (Edgar, desde la bandeja)»',
     r.estado === 409 && r.j.codigo === 'MX008' && r79.estado === 200 && r79.j.motivo_edgar === 'No es eso (Edgar, desde la bandeja)' && r79.j.fuente === 'regla', [r, r79.j]);
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  const pW3b = propDe(M3.wawa3);
  ok('E2E-80 una propuesta de REGLA rechazada no se repite para ese cargo: la siguiente ráfaga se lo da a la IA (y la IA propone 6300)',
     r.estado === 200 && r.j.reglas === 0 && pet.some((p) => /WAWA 6001/.test(contenido(p))) && pW3b?.fuente === 'ia' && pW3b.estado === 'pendiente' && pW3b.propuesta.lineas[0].cuenta === '6300',
     [{ ...r.j, detalle: undefined }, pW3b?.fuente]);

  // ---- E2E-81 las reglas: una cuenta del banco, partes, la baja --------------------------------------
  r = await llamar({ accion: 'regla_alta', nombre: 'SunPass de la tarjeta', patron: '^SUNPASS RECARGA', lineas: [{ cuenta: '6300' }], cuenta_banco: '2100-2013' }, { jwt: D2 });
  const r81 = await llamar({ accion: 'regla_alta', nombre: 'Ford Credit', patron: '^FORD CREDIT', lineas: [{ cuenta: '2520', parte: 0.8 }, { cuenta: '7100', parte: 0.2 }] }, { jwt: D2 });
  ok('E2E-81 regla_alta con su cuenta del banco (solo en la tarjeta 2100-2013) y otra de dos líneas con sus partes (80 % / 20 %)',
     r.estado === 200 && r.j.regla?.cuenta_banco === '2100-2013' && r81.estado === 200 && r81.j.regla?.lineas?.length === 2, [r.j, r81.j]);
  const M4 = { ...sembrar([{ clave: 'sp-banco', desc: 'SUNPASS RECARGA 77', monto: 20.00, dias: 1 }, { clave: 'ford', desc: 'FORD CREDIT 998877 PPD', monto: 250.00, dias: 1 }]),
               ...sembrar([{ clave: 'sp-tarjeta', desc: 'SUNPASS RECARGA 78', monto: 25.00, dias: 1 }], '2100-2013') };
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  const pSpT = propDe(M4['sp-tarjeta']), pSpB = propDe(M4['sp-banco']), pFord = propDe(M4.ford);
  ok('E2E-82 la regla de la tarjeta vale en la tarjeta y no en el banco (ese va a la IA); la de partes deja cada línea con su monto (200.00 + 50.00)',
     r.estado === 200 && pSpT?.fuente === 'regla' && pSpT.propuesta.motivo === 'Regla: SunPass de la tarjeta' && pSpB?.fuente === 'ia' && pet.some((p) => /SUNPASS RECARGA 77/.test(contenido(p)))
     && !pet.some((p) => /SUNPASS RECARGA 78|FORD CREDIT/.test(contenido(p))) && pFord?.fuente === 'regla'
     && isDeepStrictEqual(pFord.propuesta.lineas, [{ cuenta: '2520', monto: '200.00' }, { cuenta: '7100', monto: '50.00' }]), [pSpT?.propuesta, pSpB?.fuente, pFord?.propuesta]);
  r = await llamar({ accion: 'aprobar', propuesta: pFord.id }, { jwt: D2 });
  ok('E2E-83 aprobar la de partes → su asiento: 2520 200.00 + 7100 50.00 contra la 1010', r.estado === 200 && lineasDe(r.j.asiento_id) === '1010 -250.00 | 2520 200.00 | 7100 50.00', [r.j, lineasDe(r.j?.asiento_id)]);
  const M5 = sembrar([{ clave: 'wawa4', desc: 'WAWA 7002 OCALA FL', monto: 47.70, dias: 0 }]);
  await proponer();
  const pW4 = propDe(M5.wawa4);
  const reglaWawa = q(`select id from contador_reglas where nombre = 'WAWA' and activa`);
  r = await llamar({ accion: 'regla_baja', regla: reglaWawa }, { jwt: D2 });
  const r84 = await llamar({ accion: 'regla_baja', regla: 'x', motivo: 'no vale' }, { jwt: D2 });
  ok('E2E-84 regla_baja sin motivo → 400 FORMA; con una regla que no es un uuid → 400 FORMA', r.estado === 400 && r.j.codigo === 'FORMA' && r84.estado === 400 && r84.j.codigo === 'FORMA', [r, r84]);
  r = await llamar({ accion: 'regla_baja', regla: reglaWawa, motivo: 'A veces es la tienda, no la gasolina' }, { jwt: D2 });
  const vr = qj(`select row_to_json(v)::text from v_contador_reglas v where id = ${lit(reglaWawa)}`);
  ok('E2E-85 regla_baja WAWA con su motivo → activa false, el motivo en sus notas, su propuesta pendiente (WAWA 7002) caducada; v_contador_reglas la enseña dada de baja con sus veces',
     pW4?.fuente === 'regla' && r.estado === 200 && r.j.regla?.activa === false && r.j.regla.propuestas_caducadas === 1 && /A veces es la tienda/.test(r.j.regla.notas)
     && propDe(M5.wawa4).estado === 'caducada' && vr?.activa === false && vr.veces >= 3 && /6300/.test(vr.cuentas_texto ?? ''), [r.j, vr]);
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  const r86 = await llamar({ accion: 'regla_baja', regla: reglaWawa, motivo: 'otra vez' }, { jwt: D2 });
  ok('E2E-86 dada de baja, el siguiente WAWA va a la IA; darla de baja otra vez → 409 MX008',
     pet.some((p) => /WAWA 7002/.test(contenido(p))) && propDe(M5.wawa4).fuente === 'ia' && r86.estado === 409 && r86.j.codigo === 'MX008', [{ ...r.j, detalle: undefined }, r86]);

  // ---- E2E-87 caducar: una aprobada cuyo asiento se reversó (cuadre 60) ---------------------------------
  r = await llamar({ accion: 'caducar', propuesta: pW3b.id, motivo: 'no' }, { jwt: D2 });
  const r87 = await llamar({ accion: 'caducar', propuesta: pW3b.id, motivo: 'una pendiente no se caduca' }, { jwt: D2 });
  ok('E2E-87 caducar con un motivo de menos de 3 letras → 400 FORMA; caducar una pendiente → 409 MX008 (se rechaza, no se caduca)', r.estado === 400 && r.j.codigo === 'FORMA' && r87.estado === 409 && r87.j.codigo === 'MX008', [r, r87]);
  const des = descasar(M.wawa, 'prueba e2e: Edgar des-casa el WAWA de la primera ráfaga');
  const rojo60 = rojos('cuadre');
  r = await llamar({ accion: 'caducar', propuesta: pWawa.id, motivo: 'Se des-casó en la bandeja: la vuelvo a clasificar' }, { jwt: D2 });
  ok('E2E-88 des-casar en la bandeja una aprobada pone en rojo el cuadre 60; caducarla (con su motivo) la cierra «caducada» y el cuadre vuelve a verde; el cargo vuelve a esperar',
     !/^error/.test(des) && rojo60.some((x) => /^60 ia: cada propuesta aprobada o editada tiene su asiento vivo/.test(x)) && r.estado === 200 && r.j.estado === 'caducada'
     && propDe(M.wawa).estado === 'caducada' && !rojos('cuadre').some((x) => /^60 /.test(x)) && estadoMov(M.wawa) === 'pendiente|-', { des, rojo60, r: r.j });

  // ---- E2E-89 el tope ---------------------------------------------------------------------------
  const [cMes] = gastoContador();
  q(`update contador_config set tope_mes_centavos = ${cMes} where id = 1`);
  antes = await llamadasSim();
  const lotesAntes = q(`select count(*) from contador_lotes`);
  r = await proponer();
  const s89 = await llamar(null, { metodo: 'GET', consulta: '?paso=salud' });
  const e89 = qj(`select row_to_json(e)::text from v_contador_estado e`);
  const a70 = rojos('alarma').find((x) => /^70 /.test(x)) ?? '';
  ok('E2E-89 con el tope del contador gastado: proponer → bloqueado con su motivo en llano, sin llamar a la IA ni abrir ráfaga; salud y v_contador_estado lo dicen; la alarma 70 en rojo con los dólares',
     r.estado === 200 && r.j.bloqueado === true && /tope/.test(r.j.motivo) && /contador_config\.tope_mes_centavos/.test(r.j.motivo) && r.j.propuestas === 0 && r.j.con_obra === 0 && r.j.centavos === 0
     && (await llamadasSim()) === antes && q(`select count(*) from contador_lotes`) === lotesAntes && s89.j.tope?.bloqueado === true && e89?.bloqueado === true && e89.bloqueado_motivo === 'tope del contador'
     && /^70 ia: el gasto del mes bajo el tope: .*\$[0-9.,]+.*\$[0-9.,]+/.test(a70), [r.j, s89.j?.tope, e89?.bloqueado_motivo, a70]);
  ok('E2E-90 …y la base tampoco abre una ráfaga con el tope gastado (fn_contador_lote_abrir → MX008)',
     /MX008|No se abre la ráfaga/.test(qErr(`select fn_contador_lote_abrir(${lit(dueno)}, 'claude-opus-5-5', 'low', 'x', 'y', 1)`)));
  q(`update contador_config set tope_mes_centavos = 3000 where id = 1`);
  const topeApp = q(`select valor from asistente_ajustes where clave = 'tope_mes_centavos'`);
  const totalMes = q(`select coalesce(sum(centavos), 0) from asistente_costo_mes where mes = to_char(fn_fecha_miami(now()), 'YYYY-MM')`);
  q(`update asistente_ajustes set valor = ${lit(totalMes)} where clave = 'tope_mes_centavos'`);
  antes = await llamadasSim();
  r = await proponer();
  q(`update asistente_ajustes set valor = ${lit(topeApp)} where clave = 'tope_mes_centavos'`);
  ok('E2E-91 con el tope GLOBAL de la app gastado (todas las acciones del mes): bloqueado «llegó al tope de la app», sin llamar', r.estado === 200 && r.j.bloqueado === true && /tope de la app/.test(r.j.motivo) && (await llamadasSim()) === antes, r.j);
  q(`update contador_config set activa = false where id = 1`);
  antes = await llamadasSim();
  r = await proponer();
  q(`update contador_config set activa = true where id = 1`);
  ok('E2E-92 apagado (contador_config.activa = false): bloqueado «el contador está apagado», sin llamar; encendido otra vez, la alarma 70 vuelve a verde',
     r.estado === 200 && r.j.bloqueado === true && /apagado/.test(r.j.motivo) && (await llamadasSim()) === antes && !rojos('alarma').some((x) => /^70 /.test(x)), r.j);

  // ---- E2E-93 la llave, el modelo, sin llave, la base caída ---------------------------------------------
  const M6 = sembrar([{ clave: 'spotify', desc: 'SPOTIFY USA 877', monto: 11.99, dias: 0 }]);
  antes = await llamadasSim();
  r = await conEntorno({ ANTHROPIC_API_KEY: LLAVE_MALA }, (p) => llamar({ accion: 'proponer' }, { jwt: D2, puerto: p }));
  pet = await peticiones(antes);
  const lMal = qj(`select row_to_json(l)::text from (select cerrado_el, error from contador_lotes order by creado_el desc limit 1) l`);
  ok('E2E-93 una llave que Anthropic rechaza (401) → 502 ANTHROPIC_LLAVE en llano (revisa ANTHROPIC_API_KEY): corta la ráfaga en la PRIMERA petición, cierra el lote con el error y no enseña la llave',
     r.estado === 502 && r.j.codigo === 'ANTHROPIC_LLAVE' && /ANTHROPIC_API_KEY/.test(r.j.error) && pet.length === 1 && pet[0]?.cabeceras?.['x-api-key'] === 'mala' && pet[0]?.respuesta?.estado === 401
     && lMal?.cerrado_el && /llave/.test(lMal.error ?? '') && !JSON.stringify(r.j).includes('sk-ant'), [r, pet.length, lMal]);
  ok('E2E-94 …contador_config guarda el error y la alarma 72 («la última ráfaga sin error») se pone en rojo',
     q(`select (ultimo_error is not null) || '|' || (ultimo_error_el > now() - interval '5 minutes') from contador_config where id = 1`) === 'true|true' && rojos('alarma').some((x) => /^72 ia: la última ráfaga sin error/.test(x)), rojos('alarma'));
  q(`update contador_config set modelo = 'claude-fable-5' where id = 1`);
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  q(`update contador_config set modelo = 'claude-opus-5-5' where id = 1`);
  ok('E2E-95 un modelo que Anthropic no conoce (404) → 502 ANTHROPIC_MODELO: una sola petición con ESE modelo, sin probar otro (nunca un fallback)',
     r.estado === 502 && r.j.codigo === 'ANTHROPIC_MODELO' && /contador_config/.test(r.j.error) && pet.length === 1 && pet[0]?.cuerpo?.model === 'claude-fable-5', [r, pet.map((p) => p.cuerpo.model)]);
  const sin = await conEntorno({ ANTHROPIC_API_KEY: '' }, async (p) => [await llamar({ accion: 'proponer' }, { jwt: D2, puerto: p }), await llamar({ accion: 'estado' }, { jwt: D2, puerto: p })]);
  ok('E2E-96 sin ANTHROPIC_API_KEY: proponer → 500 CONFIG en llano (las reglas sí se aplicaron) y estado sigue contestando', sin[0].estado === 500 && sin[0].j.codigo === 'CONFIG' && /ANTHROPIC_API_KEY/.test(sin[0].j.error) && sin[1].estado === 200 && sin[1].j.ok, sin.map((x) => x.j));
  r = await proponer();
  ok('E2E-97 con la llave buena otra vez: la ráfaga sale bien (SPOTIFY → 3200 personal) y la alarma 72 vuelve a verde',
     r.estado === 200 && r.j.ok && propDe(M6.spotify)?.propuesta?.flags?.personal === true && !rojos('alarma').some((x) => /^72 /.test(x)), [{ ...r.j, detalle: undefined }, rojos('alarma')]);
  let s98, e98;
  if (atenderNode) {
    modulo.usarBaseDePruebas(basePsql(P_MUERTO));
    s98 = await llamar(null, { metodo: 'GET', consulta: '?paso=salud' });
    e98 = await llamar({ accion: 'estado' }, { jwt: D2 });
    modulo.usarBaseDePruebas(basePsql(PGPORT));
  } else {
    [s98, e98] = await conEntorno({ MXP_DB_URL: `postgres://editor_sql:editor_sql@127.0.0.1:${P_MUERTO}/${BD}` }, async (p) => [await llamar(null, { metodo: 'GET', consulta: '?paso=salud', puerto: p }), await llamar({ accion: 'estado' }, { jwt: D2, puerto: p })]);
  }
  ok('E2E-98 con la base caída: salud contesta 200 con base:false y «la base no contestó»; lo que pide sesión → 500 (y nada se rompe)',
     s98.estado === 200 && s98.j.base === false && s98.j.falta.some((f) => /la base no contestó/.test(f)) && e98.estado >= 500, [s98.j, e98]);

  // ---- E2E-99 dos ráfagas a la vez: una sola entra, la otra se frena en la base, ningún cargo se paga dos veces ----------
  const M7 = sembrar([
    { clave: 'shell', desc: 'SHELL OIL 57544 OCALA FL', monto: 52.00, dias: 0 },
    { clave: 'chevron', desc: 'CHEVRON 0099 LEESBURG FL', monto: 44.44, dias: 0 },
    { clave: 'racetrac', desc: 'RACETRAC 2210 OCALA FL', monto: 38.38, dias: 0 },
  ]);
  // (lo que espera ahora: los tres nuevos y los que nunca quedan —MAXTOKENS, INVALIDA—)
  const cands99 = Number(q(`select count(*) from fn_contador_candidatos()`));
  await sim('/__lento', { ms: 400 });   // (la primera ráfaga dura más de un segundo: la segunda llega con la primera en marcha)
  antes = await llamadasSim();
  const dos = await Promise.all([proponer(), proponer()]);
  await sim('/__lento', { ms: 0 });
  pet = await peticiones(antes);
  const entro = dos.filter((x) => x.estado === 200 && x.j?.ok), frenada = dos.filter((x) => x.estado === 409);
  const dobles = q(`select count(*) from (select movimiento_id from contador_propuestas where estado = 'pendiente' group by movimiento_id having count(*) > 1) x`);
  ok('E2E-99 dos «Proponer» a la vez: UNA entra (200, con todos los que esperaban) y la otra se frena en la base (409 MX008 «ya hay una ráfaga en marcha», en llano, sin gastar): la IA recibe cada cargo UNA vez, los tres nuevos tienen su propuesta, ninguno queda con dos pendientes y los lotes quedan cerrados',
     entro.length === 1 && frenada.length === 1 && frenada[0].j?.codigo === 'MX008' && /Ya hay una ráfaga en marcha/.test(frenada[0].j.error) && /espera a que termine/.test(frenada[0].j.error)
     && entro[0].j.movimientos === cands99 && entro[0].j.propuestas + entro[0].j.sin_respuesta + entro[0].j.invalidas === cands99
     && pet.length === cands99 && new Set(pet.map(claveMsg)).size === cands99 && dobles === '0' && Object.values(M7).every((m) => pendienteDe(m) !== '')
     && q(`select count(*) from contador_lotes where cerrado_el is null`) === '0' && !/40P01|deadlock/i.test(JSON.stringify(dos.map((x) => x.j)) + salidaFn),
     { cands99, pedidas: pet.length, dos: dos.map((x) => ({ estado: x.estado, ...x.j, detalle: undefined })) });

  // ---- E2E-99b el reloj de la ráfaga: una llamada en vuelo se corta al llegar el plazo, lo que no entró espera, nada se reintenta ----
  const M8 = sembrar([
    { clave: 'exxon', desc: 'EXXON 4471 OCALA FL', monto: 40.00, dias: 0 },
    { clave: 'sunoco', desc: 'SUNOCO 0912 BELLEVIEW FL', monto: 35.00, dias: 0 },
    { clave: 'peaje', desc: 'SUNPASS TOLL 8812', monto: 12.50, dias: 0 },
    { clave: 'racetrac2', desc: 'RACETRAC 2210 OCALA FL', monto: 29.90, dias: 0 },
  ]);
  const cands99b = Number(q(`select count(*) from fn_contador_candidatos()`));
  // la primera petición contesta al momento (el caché); las que siguen tardan 3,5 s, más que el reloj de 2,5 s de esta ráfaga
  await sim('/__lento', { ms: 3500, tras: 1 });
  antes = await llamadasSim();
  r = await conEntorno({ MXP_PRESUPUESTO_MS: '2500' }, (p) => llamar({ accion: 'proponer' }, { jwt: D2, puerto: p }));
  pet = await peticiones(antes);
  const porTiempo = (r.j?.detalle ?? []).filter((d) => d.estado === 'sin_respuesta' && /se acabó el tiempo de la ráfaga/.test(d.motivo ?? ''));
  const l99b = qj(`select row_to_json(l)::text from (select cerrado_el, error, n from contador_lotes where id = ${lit(r.j?.lote ?? '00000000-0000-4000-8000-000000000000')}) l`);
  // (la primera contesta al momento; el grupo de tres arranca con reloj de sobra —más de dos segundos— y se corta en vuelo al
  // llegar el plazo; el grupo que sigue ya no arranca: espera a la siguiente ráfaga)
  ok('E2E-99b el reloj de la ráfaga (2,5 s aquí, MXP_PRESUPUESTO_MS solo en el banco): la primera entra; las TRES llamadas en vuelo del grupo se cortan al llegar el plazo (sin reintento) y lo que no arrancó espera a la siguiente (nota, no error); la función vuelve al llegar el plazo y el lote queda cerrado sin error',
     r.estado === 200 && r.j.ok && r.j.presupuesto_ms === 2500 && r.j.movimientos === cands99b && r.j.ms >= 2400 && r.j.ms < 4500
     && porTiempo.length === PR.A_LA_VEZ && porTiempo.every((d) => /en vuelo se cortó al llegar el plazo/.test(d.motivo) && d.intentos === undefined)
     && (r.j.sin_intentar ?? 0) === Math.max(0, cands99b - 1 - PR.A_LA_VEZ) && ((r.j.sin_intentar ?? 0) === 0 || /esperan a la siguiente/.test(r.j.nota ?? ''))
     && pet.length === 1 + PR.A_LA_VEZ && new Set(pet.map(claveMsg)).size === pet.length
     && l99b?.cerrado_el && l99b.error === null && l99b.n === cands99b && !rojos('alarma').some((x) => /^72 /.test(x)),
     { ...r.j, detalle: undefined, porTiempo: porTiempo.length, pedidas: pet.length, l99b });
  // (las lentas siguen en vuelo en el simulador hasta que contesten: se esperan, para que lo que sigue las cuente bien)
  for (let i = 0; i < 60 && (await sim('/__estado')).en_vuelo > 0; i++) await new Promise((res) => setTimeout(res, 100));
  await sim('/__lento', { ms: 0 });

  // ---- E2E-99c una ráfaga que se cortó sin cerrar: la alarma 72 lo dice; al abrir la siguiente, la base la da por perdida ----
  const perdida = r.j?.lote;
  q(`update contador_lotes set cerrado_el = null, creado_el = now() - interval '6 minutes' where id = ${lit(perdida)}`);
  const a72 = rojos('alarma').find((x) => /^72 /.test(x)) ?? '';
  const abiertos99c = q(`select lotes_abiertos from v_contador_estado`);
  antes = await llamadasSim();
  r = await proponer();
  const lPerdida = qj(`select row_to_json(l)::text from (select cerrado_el, error, centavos from contador_lotes where id = ${lit(perdida)}) l`);
  ok('E2E-99c una ráfaga abierta hace más de 5 min (la función se cortó): la alarma 72 lo dice y v_contador_estado la cuenta; el siguiente «Proponer» la da por perdida (cerrada con su error, 0 centavos, el error en contador_config), entra, y como cerró limpio la alarma 72 vuelve a verde',
     /^72 ia: la última ráfaga sin error: 1 ráfaga\(s\) abierta\(s\) desde las .* sin cerrar: la función se cortó/.test(a72) && abiertos99c === '1'
     && r.estado === 200 && r.j.ok && r.j.propuestas >= 4 && lPerdida?.cerrado_el && /se cortó sin cerrar/.test(lPerdida.error ?? '') && lPerdida.centavos === 0
     && q(`select (ultimo_error ~ 'se cortó sin cerrar') || '|' || (ultima_rafaga_el > ultimo_error_el) from contador_config`) === 'true|true'
     && q(`select lotes_abiertos from v_contador_estado`) === '0' && !rojos('alarma').some((x) => /^72 /.test(x))
     && Object.values(M8).every((m) => pendienteDe(m) !== ''), { a72, abiertos99c, r: { ...r.j, detalle: undefined }, lPerdida });

  // ---- E2E-118 LA OBRA (7b) de punta a punta: la IA la propone con las pistas, una que no existe, una que no se atreve, ----
  //      el cuadre 64, «Así es» sin elegir, y el siguiente del comercio por la regla aprendida con la candidata
  // LAS PISTAS, sembradas aquí: 24 h de la cuadrilla en OBRA de anteayer a hoy (a nombre del equipo; una fila con la nota
  // que no debe salir), un ticket de CES a OBRA hace 20 días («por leer» y sin total: ni el puente lo postea ni explica el
  // cargo) y una fila de su lista de materiales hoy. LAS CUENTAS, para cualquier día: las tres compras de hoy suman en OBRA
  // 24×2 + 24×0,2 + (la semilla: ≤ 6) y el CES además 6 del ticket y 1 del material: 52,8 o más, contra 4,8 de OBRA3 (sus
  // 24 h de hace una semana, en el mes) y ≤ 3,9 de la oficina: OBRA es la candidata de las tres.
  q(`insert into horas (fecha, usuario_id, proyecto_id, horas, notas) values
       (${lit(diaMenos(2))}, ${lit(equipo)}, ${lit(OBRA)}, 8, ${lit(NOTA_SECRETA)}),
       (${lit(diaMenos(1))}, ${lit(equipo)}, ${lit(OBRA)}, 8, null),
       (${lit(diaMenos(0))}, ${lit(equipo)}, ${lit(OBRA)}, 8, null);
     insert into recibos (proyecto_id, ruta, proveedor, estado, autor_id, fecha, creado)
       values (${lit(OBRA)}, 'recibos/e2e-c8/ces-0001.jpg', 'CES', 'por_leer', ${lit(equipo)}, ${lit(diaMenos(20))}, ${lit(`${diaMenos(20)} 12:00 America/New_York`)}::timestamptz);
     insert into materiales (proyecto_id, descripcion, estado, autor_id, creado)
       values (${lit(OBRA)}, 'E2E-C8 BREAKER 20A', 'falta', ${lit(equipo)}, now())`);
  // (las tres compras de hoy: el CES de Edgar —«CES 1040 TAMPA FL · 5100 Material · Pide obra», el que pidió la 7b—, una
  // a la que el simulador le inventa la obra «no-existe» y una con la que no se atreve aunque haya candidata)
  const M9 = sembrar([
    { clave: 'ces', desc: 'CES 1040 TAMPA FL', monto: 186.40, dias: 0 },
    { clave: 'lowes-mala', desc: 'LOWES 1077 OCALA FL OBRA MALA', monto: 58.25, dias: 0 },
    { clave: 'ferre-sin', desc: 'FERRETERIA EL TORNILLO SIN OBRA', monto: 33.10, dias: 0 },
  ]);
  const conObra0 = Number(q(`select propuestas_con_obra from v_contador_estado`));
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  const P7 = r.j ?? {};
  const det7 = (mov) => (P7.detalle ?? []).find((x) => x.movimiento_id === mov);
  const anot7 = (re) => pet.filter((p) => re.test(contenido(p))).pop();
  const msg7 = (re) => msgDe(anot7(re) ?? {});
  const pCes = propDe(M9.ces), pMala = propDe(M9['lowes-mala']), pSin = propDe(M9['ferre-sin']);
  const mCes = msg7(/CES 1040/), mMala = msg7(/OBRA MALA/), mSin = msg7(/SIN OBRA/);
  const oCes = obraP(mCes?.pistas_obra, OBRA);
  ok('E2E-118 (7b) la ráfaga de la obra: las tres compras de hoy llegan a la IA con candidata OBRA (las 24 h de la cuadrilla estos días; el CES suma su ticket anterior y la lista de materiales), las del CES son las de la base sin puntos, y con_obra = 1 (solo el CES: la obra inventada se descarta y la otra no se atrevió) = el detalle con obra = las pendientes del lote con obra; v_contador_estado suma una',
     r.estado === 200 && P7.ok === true && P7.propuestas === 3 && P7.con_obra === 1 && (P7.detalle ?? []).filter((d) => d.obra).length === 1 && det7(M9.ces)?.obra === OBRA
     && Number(q(`select count(*) from contador_propuestas where lote_id = ${lit(RE_UUID.test(P7.lote ?? '') ? P7.lote : UUID_NADA)} and estado = 'pendiente' and jsonb_typeof(propuesta->'obra') = 'object'`)) === 1
     && [mCes, mMala, mSin].every((m) => formaPistas(m?.pistas_obra) && m.pistas_obra.candidata?.proyecto_id === OBRA)
     && isDeepStrictEqual(mCes.pistas_obra, sinPuntos(pCes?.pistas)) && oCes?.horas_cerca === 24 && oCes.recibos_proveedor === 1 && oCes.materiales_recientes === 1 && oCes.veces_elegida === 0
     && /^la cuadrilla reportó 24 h en .+ esos días.*; 1 compra anterior de CES fue a esa obra; hay 1 material de su lista apuntado estos días$/.test(mCes.pistas_obra.candidata.motivo)
     && Number(q(`select propuestas_con_obra from v_contador_estado`)) === conObra0 + 1,
     { ...P7, detalle: (P7.detalle ?? []).map((d) => [d.estado, d.obra, d.obra_nota]), ces: mCes?.pistas_obra });
  const bCes = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M9.ces)}`);
  ok('E2E-119 (7b) LA IA PROPONE LA OBRA del CES: la línea 5100 con OBRA, pide_obra false, flags.obra_propuesta, propuesta.obra {OBRA, 0.8, el motivo de la pista}, sin nota; v_contador_bandeja con obra_propuesta_id, su nombre, obra_confianza 0.8, obra_motivo y pistas_resumen (lo que pinta «Según la IA»)',
     pCes?.fuente === 'ia' && pCes.estado === 'pendiente' && isDeepStrictEqual(pCes.propuesta.lineas, [{ cuenta: '5100', proyecto_id: OBRA }]) && isDeepStrictEqual(pCes.propuesta.flags, { obra_propuesta: true })
     && isDeepStrictEqual(pCes.propuesta.obra, { proyecto_id: OBRA, confianza: 0.8, motivo: mCes?.pistas_obra?.candidata?.motivo }) && pCes.nota === null && det7(M9.ces)?.pide_obra === false
     && bCes?.obra_propuesta_id === OBRA && bCes.obra_propuesta === OBRA_NOMBRE && Number(bCes.obra_confianza) === 0.8 && bCes.obra_motivo === pCes.propuesta.obra.motivo
     && bCes.pistas_resumen === pCes.pistas?.resumen && bCes.pide_obra === false && bCes.lineas?.[0]?.obra === OBRA_NOMBRE && bCes.lineas[0].pide_obra === false, [pCes?.propuesta, bCes]);
  const NOTA_MALA = 'la IA propuso la obra «no-existe», que no existe: la propuesta se guarda sin obra';
  const bMala = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M9['lowes-mala'])}`);
  ok('E2E-120 (7b) UNA OBRA QUE NO EXISTE (la IA propone «no-existe») → la propuesta se guarda SIN obra, con pide_obra y la nota que lo dice; el detalle trae obra_nota y no obra; la bandeja, sin obra propuesta y con la nota',
     anot7(/OBRA MALA/)?.obra === 'no-existe' && pMala?.estado === 'pendiente' && isDeepStrictEqual(pMala.propuesta.lineas, [{ cuenta: '5100' }])
     && isDeepStrictEqual(pMala.propuesta.flags, { pide_obra: true }) && pMala.propuesta.obra === undefined && pMala.nota === NOTA_MALA
     && det7(M9['lowes-mala'])?.obra_nota === NOTA_MALA && det7(M9['lowes-mala']).obra === undefined && det7(M9['lowes-mala']).pide_obra === true
     && bMala?.obra_propuesta_id === null && bMala.pide_obra === true && bMala.nota === NOTA_MALA, [pMala?.propuesta, pMala?.nota, det7(M9['lowes-mala'])]);
  const bSin = qj(`select row_to_json(b)::text from v_contador_bandeja b where movimiento_id = ${lit(M9['ferre-sin'])}`);
  ok('E2E-121 (7b) LA IA QUE NO SE ATREVE (obra null aunque las pistas traen candidata OBRA) → sin obra, pide_obra, sin nota; la bandeja enseña las pistas (pistas_resumen: OBRA con sus horas de estos días) para que Edgar elija',
     anot7(/SIN OBRA/)?.candidata === OBRA && anot7(/SIN OBRA/).obra === null && pSin?.estado === 'pendiente' && isDeepStrictEqual(pSin.propuesta.lineas, [{ cuenta: '5100' }])
     && isDeepStrictEqual(pSin.propuesta.flags, { pide_obra: true }) && pSin.propuesta.obra === undefined && pSin.nota === null
     && det7(M9['ferre-sin'])?.obra === undefined && det7(M9['ferre-sin']).obra_nota === undefined && det7(M9['ferre-sin']).pide_obra === true
     && bSin?.obra_propuesta_id === null && bSin.pide_obra === true && bSin.pistas_resumen === pSin.pistas?.resumen && bSin.pistas_resumen.startsWith(`${OBRA_NOMBRE}: 24 h esos días`),
     [pSin?.propuesta, bSin?.pistas_resumen, anot7(/SIN OBRA/)?.candidata]);
  // el cuadre 64: la obra propuesta del CES, por un momento, una que no existe (como si la hubieran borrado o cerrado)
  const propCes = q(`select propuesta::text from contador_propuestas where id = ${lit(pCes?.id ?? UUID_NADA)}`);
  q(`update contador_propuestas set propuesta = jsonb_set(propuesta, '{obra,proyecto_id}', '"e2e-obra-cerrada"') where id = ${lit(pCes?.id ?? UUID_NADA)}`);
  const rojo64 = rojos('cuadre');
  q(`update contador_propuestas set propuesta = ${lit(propCes)}::jsonb where id = ${lit(pCes?.id ?? UUID_NADA)}`);
  ok('E2E-122 (7b) el cuadre 64: una obra propuesta pendiente que ya no es una obra activa (aquí, una que no existe) lo pone en rojo, con la propuesta y qué hacer; de vuelta, verde',
     rojo64.some((x) => /^64 ia: toda obra propuesta pendiente es una obra activa: .*«e2e-obra-cerrada» no existe → recházala/.test(x)) && !rojos('cuadre').some((x) => /^64 /.test(x)), rojo64);
  // (31-oct) LA OBRA QUE SE CIERRA DESPUÉS DE PROPONERLA: la del CES (OBRA, activa y propuesta) se completa en la app; el 64 la
  // nombra; y la base no la deja entrar por un toque: «Así es» sin elegir (entraría la propuesta), «Así es» con esa misma obra
  // (lo que manda una bandeja abierta hace rato) y «Según yo» con ella en la línea contestan 409 MX008 «ya no está activa» con
  // la pista «elige la obra», que la pantalla enseña en ámbar junto al selector; nada entra; otra vez activa, el 64 en verde
  const estadoObra = q(`select estado from proyectos where id = ${lit(OBRA)}`);
  q(`update proyectos set estado = 'completado' where id = ${lit(OBRA)}`);
  const rojo64b = rojos('cuadre');
  const asientosCerrada = q(`select count(*) from asientos`);
  const rC1 = await llamar({ accion: 'aprobar', propuesta: pCes?.id }, { jwt: D2 });
  const rC2 = await llamar({ accion: 'aprobar', propuesta: pCes?.id, proyecto_id: OBRA }, { jwt: D2 });
  const rC3 = await llamar({ accion: 'clasificar', movimiento: M9.ces, lineas: [{ cuenta: '5100', proyecto_id: OBRA }], motivo: 'según yo, con la obra que se cerró', recordar: false }, { jwt: D2 });
  q(`update proyectos set estado = ${lit(estadoObra)} where id = ${lit(OBRA)}`);
  const frenada64 = (x) => x.estado === 409 && x.j?.codigo === 'MX008' && x.j.pista === 'elige la obra' && /ya no está activa \(está completado\)/.test(x.j.error ?? '');
  ok('E2E-128 (31-oct) LA OBRA QUE SE CIERRA DESPUÉS DE PROPONERLA no entra por un toque: con OBRA completada el 64 la nombra («la obra propuesta «OBRA» está completado»); «Así es» sin elegir, «Así es» con esa misma obra y «Según yo» con ella en la línea → 409 MX008 «ya no está activa» con la pista «elige la obra»; nada entra al libro y la propuesta sigue pendiente; activa otra vez, el 64 en verde',
     rojo64b.some((x) => new RegExp(`^64 .*la obra propuesta «${escRe(OBRA_NOMBRE)}» está completado`).test(x)) && frenada64(rC1) && frenada64(rC2) && frenada64(rC3)
     && /^La obra propuesta «/.test(rC1.j?.error ?? '') && /^La obra «/.test(rC2.j?.error ?? '') && /^Línea 1: la obra «/.test(rC3.j?.error ?? '')
     && q(`select count(*) from asientos`) === asientosCerrada && propDe(M9.ces)?.estado === 'pendiente' && estadoMov(M9.ces) === 'pendiente|-'
     && !rojos('cuadre').some((x) => /^64 /.test(x)), { rojo64b, rC1: rC1.j, rC2: rC2.j, rC3: rC3.j });
  // «Así es» sin elegir: entra la obra propuesta
  r = await llamar({ accion: 'aprobar', propuesta: pCes?.id }, { jwt: D2 });
  const aCes = propDe(M9.ces);
  const rgCes = qj(`select row_to_json(x)::text from (select id, nombre, patron, lineas, pide_obra, origen from contador_reglas where id = ${lit(r.j?.regla?.regla ?? UUID_NADA)}) x`);
  ok('E2E-123 (7b) «ASÍ ES» SIN ELEGIR LA OBRA → aprobada con la obra propuesta: el asiento 5100 con OBRA, las líneas finales con OBRA; y la regla del comercio («CES») nace SIN la obra y pide obra',
     r.estado === 200 && r.j.estado === 'aprobada' && r.j.fuente === 'ia' && isDeepStrictEqual(r.j.lineas, [{ cuenta: '5100', proyecto_id: OBRA }])
     && lineasDe(r.j.asiento_id) === `1010 -186.40 | 5100 186.40 @${OBRA}` && asientoVivo(r.j.asiento_id) && aCes?.estado === 'aprobada'
     && isDeepStrictEqual(aCes.lineas_finales, [{ cuenta: '5100', proyecto_id: OBRA }]) && r.j.regla?.nueva === true && /^\^CES/.test(rgCes?.patron ?? '')
     && isDeepStrictEqual(rgCes.lineas, [{ cuenta: '5100' }]) && rgCes.pide_obra === true && rgCes.origen === 'aprobacion', [r.j, rgCes]);
  r = await llamar({ accion: 'aprobar', propuesta: pMala?.id }, { jwt: D2 });
  const r124 = await llamar({ accion: 'aprobar', propuesta: pMala?.id, proyecto_id: OBRA2, recordar: false }, { jwt: D2 });
  ok('E2E-124 (7b) la de la obra descartada: aprobar sin elegir → 409 MX008 «elige la obra» (la IA la propuso, pero no valía: no entra nada); eligiendo OBRA2 → aprobada (no había obra propuesta: la de Edgar), su asiento con OBRA2',
     r.estado === 409 && r.j.codigo === 'MX008' && r.j.pista === 'elige la obra' && /5100/.test(r.j.error) && r124.estado === 200 && r124.j.estado === 'aprobada'
     && lineasDe(r124.j.asiento_id) === `1010 -58.25 | 5100 58.25 @${OBRA2}` && r124.j.regla === undefined, [r, r124.j]);
  // el siguiente CES: por la regla aprendida (la cuenta) con la candidata de las pistas (la obra)
  const M10 = sembrar([{ clave: 'ces2', desc: 'CES 1040 TAMPA FL', monto: 64.20, dias: 0 }]);
  antes = await llamadasSim();
  r = await proponer();
  pet = await peticiones(antes);
  const pC2 = propDe(M10.ces2);
  const candC2 = pC2?.pistas?.candidata;
  ok('E2E-125 (7b) el siguiente CES sale por la REGLA aprendida (que no guarda obra) CON la candidata de las pistas: OBRA —Edgar la eligió la última vez con CES, y las horas, el ticket y la lista—; la línea 5100 con OBRA, propuesta.obra con su confianza y su motivo; la IA no lo ve (con_obra 0)',
     r.estado === 200 && r.j.reglas === 1 && r.j.con_obra === 0 && !pet.some((p) => /CES 1040/.test(contenido(p))) && pC2?.fuente === 'regla' && pC2.regla_id === rgCes?.id
     && pC2.propuesta.motivo === `Regla: ${rgCes?.nombre}` && pC2.propuesta.confianza === 1 && candC2?.proyecto_id === OBRA && obraP(pC2.pistas, OBRA)?.veces_elegida === 1
     && /Edgar eligió esa obra la última vez con CES/.test(candC2.motivo) && isDeepStrictEqual(pC2.propuesta.lineas, [{ cuenta: '5100', proyecto_id: OBRA }])
     && isDeepStrictEqual(pC2.propuesta.flags, { obra_propuesta: true }) && isDeepStrictEqual(pC2.propuesta.obra, { proyecto_id: OBRA, confianza: candC2.confianza, motivo: candC2.motivo }),
     [{ ...r.j, detalle: undefined }, pC2?.propuesta, candC2]);
  r = await llamar({ accion: 'aprobar', propuesta: pC2?.id, proyecto_id: OBRA2 }, { jwt: D2 });
  ok('E2E-126 (7b) aprobar la de la regla con OTRA obra (OBRA2; las pistas decían OBRA) → editada, el asiento con OBRA2, y la regla CES sigue igual: sin obra (nueva false, cambio false)',
     r.estado === 200 && r.j.estado === 'editada' && r.j.fuente === 'regla' && lineasDe(r.j.asiento_id) === `1010 -64.20 | 5100 64.20 @${OBRA2}` && r.j.regla?.nueva === false && r.j.regla.cambio === false
     && q(`select lineas::text || '|' || pide_obra from contador_reglas where id = ${lit(rgCes?.id ?? UUID_NADA)}`) === '[{"cuenta": "5100"}]|true', r.j);
  // nada personal, en toda la prueba: lo que llegó a la IA, lo que contestó la función, lo que escribió y lo que guardó c8
  const todasPet = await peticiones();
  const conMensaje = todasPet.filter((p) => p.movimiento_json !== undefined);
  const filasC8 = q(`select coalesce((select string_agg(x::text, '') from contador_propuestas x), '') || coalesce((select string_agg(x::text, '') from contador_lotes x), '') || coalesce((select string_agg(x::text, '') from contador_reglas x), '')`);
  const fugas = [['mensajes a la IA', personal(textoMensajes(todasPet))],
    ['respuestas de la función', [NOTA_SECRETA, equipo].filter((x) => respuestas.join('\n').includes(x))], ['salida de la función', [NOTA_SECRETA, equipo].filter((x) => salidaFn.includes(x))],
    ['el simulador', [NOTA_SECRETA, equipo].filter((x) => JSON.stringify(todasPet).includes(x))], ['tablas del contador', [NOTA_SECRETA, equipo, 'recibos/'].filter((x) => filasC8.includes(x))]]
    .filter(([, xs]) => xs.length);
  ok('E2E-127 (7b) NADA PERSONAL en toda la prueba: todas las peticiones con mensaje trajeron sus pistas, y ni la nota de las horas, ni el id ni el nombre de quien las reportó, ni la ruta del ticket salen a la IA, en una respuesta, en la salida de la función ni en las tablas del contador',
     conMensaje.length >= 30 && conMensaje.every((p) => p.pistas_obra === true) && fugas.length === 0, fugas);

  // ---- E2E-100 el control y sus alarmas ----------------------------------------------------------
  const pend = pendienteDe(M7.shell);
  q(`update contador_propuestas set creado_el = creado_el - interval '8 days' where id = ${lit(pend)}`);
  const a71 = rojos('alarma').find((x) => /^71 /.test(x)) ?? '';
  q(`update contador_propuestas set creado_el = creado_el + interval '8 days' where id = ${lit(pend)}`);
  ok('E2E-100 una propuesta pendiente de más de 7 días pone en rojo la alarma 71 (con el cargo); al día, verde', /^71 ia: ninguna propuesta pendiente de más de 7 días: .*SHELL OIL/.test(a71) && !rojos('alarma').some((x) => /^71 /.test(x)), a71);
  const ctl = control();
  const nombres = Object.fromEntries(ctl.map((c) => [c.orden, `${c.nivel}|${c.control}`]));
  ok('E2E-101 v_contador_control trae los cuadres 60–64 (el 64, de la 7b) y las alarmas 70–73 del contrato',
     nombres[60] === 'cuadre|ia: cada propuesta aprobada o editada tiene su asiento vivo' && nombres[61] === 'cuadre|ia: ningún asiento con «Propuesta de la IA #» en su motivo sin su propuesta aprobada'
     && nombres[62] === 'cuadre|ia: las reglas activas van a cuentas activas e imputables' && nombres[63] === 'cuadre|ia: protecciones de la fase 7'
     && nombres[64] === 'cuadre|ia: toda obra propuesta pendiente es una obra activa'
     && nombres[70] === 'alarma|ia: el gasto del mes bajo el tope' && nombres[71] === 'alarma|ia: ninguna propuesta pendiente de más de 7 días'
     && nombres[72] === 'alarma|ia: la última ráfaga sin error' && nombres[73] === 'alarma|ia: la llave y la función', nombres);
  ok('E2E-102 v_contador_control en verde: ningún cuadre ni alarma en rojo', rojos('cuadre').length === 0 && rojos('alarma').length === 0, [rojos('cuadre'), rojos('alarma')]);
  const viaIA = qj(`select coalesce(json_agg(json_build_object('p', p.id, 'a', p.asiento_id, 'origen', a.origen_tabla, 'u', a.usuario_id)), '[]')::text from contador_propuestas p join asientos a on a.id = p.asiento_id where p.estado in ('aprobada', 'editada')`);
  ok('E2E-103 todo lo que entró al libro por el contador es de c6 (origen movimientos_banco), en nombre del dueño, con su asiento vivo (una aprobación = un asiento)',
     viaIA.length >= 10 && viaIA.every((x) => x.origen === 'movimientos_banco' && x.u === dueno && asientoVivo(x.a)) && new Set(viaIA.map((x) => x.a)).size === viaIA.length, viaIA.length);

  // ---- E2E-104 la API: lo que lee el dueño y lo que nadie ejecuta ------------------------------------
  const CL_D = { sub: dueno, role: 'authenticated', aal: 'aal2' }, CL_E = { sub: equipo, role: 'authenticated', aal: 'aal2' };
  const veDueno = qComo(CL_D, 'authenticated', `select (select count(*) from v_contador_bandeja) > 0 and (select count(*) from v_contador_reglas) > 0 and (select count(*) from v_contador_estado) = 1 and (select count(*) from v_contador_control) > 0 and (select count(*) from contador_propuestas) > 0`);
  const veEquipo = qComo(CL_E, 'authenticated', `select (select count(*) from v_contador_bandeja) + (select count(*) from contador_propuestas) + (select count(*) from contador_reglas) + (select count(*) from contador_config)`);
  const veAnon = qComo({ role: 'anon' }, 'anon', `select count(*) from v_contador_bandeja`);
  ok('E2E-104 por la API: el dueño (aal2) lee las vistas y las tablas de c8; el equipo no ve ninguna fila; anon ni siquiera puede leer',
     veDueno === 't' && veEquipo === '0' && /permission denied|42501/.test(veAnon), { veDueno, veEquipo, veAnon });
  const ejecuta = ['fn_contador_aprobar(gen_random_uuid(), gen_random_uuid())', 'fn_contador_pendientes(1)', 'fn_contador_reglas_aplicar(gen_random_uuid())', 'fn_contador_tope()']
    .map((f) => [f, qComo(CL_D, 'authenticated', `select ${f} is not null`), qComo({ role: 'service_role' }, 'service_role', `select ${f} is not null`)]);
  ok('E2E-105 por la API nadie ejecuta una fn_contador_* (ni el dueño en aal2 ni service_role): permiso denegado', ejecuta.every(([, a, b]) => /permission denied/.test(a) && /permission denied/.test(b)), ejecuta);
  const enApi = q(`select coalesce(string_agg(p.oid::regprocedure::text || ' → ' || g, ', '), 'ninguna') from pg_proc p, unnest(array['anon','authenticated','service_role']) g where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\\_contador\\_%' and (has_function_privilege(g, p.oid, 'execute') or p.prosecdef)`);
  ok('E2E-106 ninguna fn_contador_* ejecutable por la API ni SECURITY DEFINER (y son las de c8: todas con su comment «c8:»)',
     enApi === 'ninguna' && q(`select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'fn\\_contador\\_%' and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'c8:%'`) === '0', enApi);
  const tablasC8 = q(`select string_agg(c.relname || ':' || c.relrowsecurity || ':' || (select string_agg(pl.polname || '/' || pl.polcmd::text, ',') from pg_policy pl where pl.polrelid = c.oid) || ':' || (select count(*) from pg_trigger t where t.tgrelid = c.oid and not t.tgisinternal), ' ' order by c.relname) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname in ('contador_config', 'contador_reglas', 'contador_lotes', 'contador_propuestas')`);
  ok('E2E-107 las cuatro tablas con RLS y UNA sola policy «<tabla>_dueno» de lectura, y ningún trigger',
     tablasC8 === 'contador_config:true:contador_config_dueno/r:0 contador_lotes:true:contador_lotes_dueno/r:0 contador_propuestas:true:contador_propuestas_dueno/r:0 contador_reglas:true:contador_reglas_dueno/r:0', tablasC8);

  // ---- E2E-108 el cierre -------------------------------------------------------------------------
  const rojosOtros = q(`select coalesce(string_agg(x, '; '), 'ninguno') from (select 'c2 ' || control as x from fn_verificar_cadena() where not ok union all select 'c6 ' || vista from fn_banco_control('hoy') where not ok union all select 'c4 ' || vista from fn_estados_control('hoy') where not ok and vista <> 'cuadre: apertura en el libro' union all select 'c3 ' || control from fn_puentes_verificar() where not ok) r`);
  ok('E2E-108 fn_verificar_cadena, fn_banco_control(hoy), fn_puentes_verificar y fn_estados_control(hoy) sin rojos (salvo la apertura de fábrica)', rojosOtros === 'ninguno', rojosOtros);
  const simTexto = JSON.stringify(await sim('/__peticiones')) + JSON.stringify(await sim('/__estado'));
  const tablas = q(`select coalesce((select string_agg(x::text, '') from contador_propuestas x), '') || coalesce((select string_agg(x::text, '') from contador_lotes x), '') || coalesce((select string_agg(x::text, '') from contador_config x), '') || coalesce((select string_agg(x::text, '') from contador_reglas x), '') || coalesce((select string_agg(x::text, '') from asistente_uso x), '')`);
  const dondeLlaves = [['respuestas de la función', respuestas.join('\n')], ['salida de la función', salidaFn], ['peticiones y estado del simulador', simTexto], ['tablas ia_* y asistente_uso', tablas], ['salida de esta prueba', salidaE2E]]
    .filter(([, s]) => s.includes(LLAVE)).map(([n]) => n);
  ok('E2E-109 la llave de prueba (sk-ant-prueba…) no sale en ninguna respuesta, ni en la salida de la función ni en la de la prueba, ni en el simulador, ni en las tablas',
     dondeLlaves.length === 0 && respuestas.length > 50, dondeLlaves);
} catch (e) {
  ok('la prueba corrió entera', false, (e && e.stack) || String(e));
}
limpiarHijos();
const malas = resultados.filter((x) => !x.ok).length;
if (malas && salidaFn.trim()) escribir('--- lo que escribió la función ---\n' + salidaFn.slice(-3000));
escribir(`CONTADOR-E2E (${CON_DENO ? 'deno' : 'node'}) total=${resultados.length} ok=${resultados.length - malas} fallan=${malas}${process.env.CONSERVAR ? ` (la base ${BD} se queda)` : ''}`);
if (!process.env.CONSERVAR && !process.env.SIN_CONSTRUIR) { try { execFileSync('./correr.sh', ['--borrar', BD], { cwd: AQUI, env: { ...process.env, PGHOST: '127.0.0.1', PGPORT }, stdio: 'ignore' }); } catch { /* queda */ } }
process.exit(malas ? 1 : 0);
