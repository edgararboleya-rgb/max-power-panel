/* f19-capturar.js — LA BASE SIMULADA de la Bandeja nueva (c17) y de las
   cuentas y reportes en inglés (c18) de pruebas/conta/pantalla.js, SACADA
   DEL BANCO.

   Como el tablero (f16): no hay una mentira escrita a mano para lo que la
   base contesta. Cada respuesta que la pantalla recibe en pantalla.js de
   fn_bandeja_* y de fn_fiscal_* es la que dio el banco (Postgres 17 en
   127.0.0.1:5433) a esa misma llamada, como el dueño (authenticated, aal2).
   Este script:
     1. arma <bd> (BORRA la que haya con ese nombre): un clon de la plantilla
        (de fábrica g16a: producción con la lista v305) con las capas del
        árbol que han cambiado desde entonces, en el orden en que las pega
        Edgar (c3, c6 en dos partes, c10, c15, c16), y encima c17-bandeja.sql,
        c18-fiscal.sql y f19-semilla.sql (una Bandeja con veinte movimientos
        inventados: comercios, un prestamista, el depósito de un procesador
        de tarjetas, un Zelle, el cajero, cuotas, intereses);
     2. le pide a la base, como el dueño, lo que la pantalla pide: la
        Bandeja (v_banco_bandeja), fn_bandeja_leer, las facturas por cobrar;
        y, CADA UNO EN UNA TRANSACCIÓN QUE SE DESHACE, lo que contesta cada
        «Así es» que la pantalla prueba y cómo queda la Bandeja después (lo
        que se lee): la recomendación de un gasto, la de un gasto de obra
        (con la obra del día y sin obra), el préstamo, el depósito del
        procesador con sus dos facturas y su comisión, el Zelle de una LLC,
        un pago parcial elegido a mano, dinero del dueño sin y con su
        porqué, los lotes del banco y un grupo; LA CADENA de lo que entra
        solo (un grupo con «que lo siguiente entre solo», llega otro cargo y
        entra solo, se deshace, se apaga, se olvida); lo que el «Dímelo»
        guarda para varias respuestas de la IA (la función de borde no se
        llama aquí: su respuesta va escrita, como la daría el simulador, y lo
        que se captura es lo que la BASE valida y guarda), aprobar y
        rechazar; la propuesta de la IA de c8 aprobada por su puerta; y lo
        fiscal: fn_fiscal_leer, el paquete del año con el 1120 y con el
        1120-S, y la forma confirmada;
     3. revisa que en lo capturado no salga ningún nombre de la semilla de
        siempre (los ids de obra de 02-semilla.sql son inventados y ya son
        públicos: se quitan antes de revisar);
     4. escribe pruebas/conta/pantalla-f19.json, con la huella de c17, de
        c18 y de la semilla (pantalla.js las compara con las del árbol).
   Los números son los del banco el día en que se capturó (las fechas son
   de los doce días anteriores). Si c17, c18 o la semilla cambian, se vuelve
   a correr.

   Uso (solo el banco; nada de red):
     node pruebas/conta/f19-capturar.js <bd> [plantilla=g16a]
   Tarda unos 20 s. La base queda; se borra a mano:
     runuser -u postgres -- psql -X -h /var/run/postgresql -p 5433 -c "drop database <bd>" */
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const { execFileSync } = require('child_process');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--'));
const BD = ARGS[0], PLANTILLA = ARGS[1] || 'g16a';
const SAGRADAS = ['g16a', 'g15a', 'g12a', 'g10a', 'g9a', 'g8a', 'f9fix', 'p1fab', 'c9perf', PLANTILLA];
if (!BD || !/^[a-z][a-z0-9_]*$/.test(BD) || SAGRADAS.includes(BD)) {
  console.error('uso: node pruebas/conta/f19-capturar.js <bd nueva> [plantilla=g16a]   (nunca una plantilla)'); process.exit(2);
}
const ROOT = path.resolve(__dirname, '..', '..');
const SALIDA = path.join(__dirname, 'pantalla-f19.json');
const ENV = { ...process.env, PGHOST: '127.0.0.1', PGPORT: '5433', PGPASSWORD: 'editor_sql' };
const DUENO = '00000000-0000-4000-a000-000000000001';
const huella = f => crypto.createHash('sha1').update(fs.readFileSync(path.join(ROOT, f))).digest('hex').slice(0, 12);
const CAPAS = ['docs/conta/c3-puentes.sql', 'docs/conta/c6-banco-parte1.sql', 'docs/conta/c6-banco-parte2.sql', 'docs/conta/c10-costo-obra.sql',
  'docs/conta/c15-nomina.sql', 'docs/conta/c16-tablero.sql', 'docs/conta/c17-bandeja.sql', 'docs/conta/c18-fiscal.sql'];
const SEMILLA = 'pruebas/conta/f19-semilla.sql';

// ---------- el banco ----------
const su = sql => execFileSync('runuser', ['-u', 'postgres', '--', 'psql', '-X', '-q', '-h', '/var/run/postgresql', '-p', '5433', '-v', 'ON_ERROR_STOP=1', '-c', sql], { stdio: ['ignore', 'pipe', 'pipe'] });
const pegar = (archivo, una = true) => execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, ...(una ? ['-1'] : []), '-f', path.join(ROOT, archivo)], { env: ENV, stdio: ['ignore', 'pipe', 'pipe'] });
const psql = sql => execFileSync('psql', ['-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-U', 'editor_sql', '-d', BD, '-f', '-'], { env: ENV, input: sql, stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 1 << 28 }).toString();
const dolar = s => { let t = 'q'; while (s.includes(`$${t}$`)) t += 'x'; return `$${t}$${s}$${t}$`; };
// Una orden como la pantalla por PostgREST (quien: dueno, con su código del teléfono) o como la función de borde y el SQL
// Editor (quien: editor): la consulta devuelve un jsonb. Un error vuelve como {ERROR, message}. Todas las órdenes de una
// llamada van en UNA transacción que se deshace: lo que una hace lo ve la siguiente, y nada queda
const AYUDA = `
create or replace function pg_temp.pedir(p_sql text, p_quien text) returns jsonb language plpgsql as $f$
declare v jsonb; c text; m text;
begin
  if p_quien = 'dueno' then
    perform set_config('request.jwt.claims', json_build_object('sub', '${DUENO}', 'role', 'authenticated', 'aal', 'aal2')::text, true);
    perform set_config('request.jwt.claim.sub', '${DUENO}', true);
    execute 'set local role authenticated';
  end if;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics c = returned_sqlstate, m = message_text;
    v := jsonb_build_object('ERROR', c, 'message', m);
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  return v;
end $f$;
-- un cargo más que llega del banco (como en la semilla)
create or replace function pg_temp.llega(p_clave text, p_dias int, p_monto numeric, p_desc text) returns jsonb language plpgsql as $f$
declare v_mov uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', '${DUENO}', 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', '${DUENO}', true);
  perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '1010', 'nombre', 'Plaid · f19-capturar · ' || p_clave,
    'filas', jsonb_build_array(jsonb_build_object('id', 'ZZ19-' || p_clave, 'fecha', (fn_fecha_miami(now()) - p_dias)::text, 'plaid_monto', (-p_monto)::text,
             'descripcion', p_desc, 'tipo', 'DEBIT', 'pendiente', false))));
  select m.id into v_mov from movimientos_banco m where m.id_externo = 'ZZ19-' || p_clave order by m.importado_el desc limit 1;
  perform fn_banco_casar(v_mov);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  insert into public.f19_semilla (clave, movimiento, nota) values (p_clave, v_mov, p_desc);
  return to_jsonb(v_mov::text);
end $f$;`;
function pedir(ordenes) {
  const sql = ['begin;', AYUDA, ...ordenes.map(o => `select coalesce(pg_temp.pedir(${dolar(o.sql)}, '${o.quien || 'dueno'}')::text, 'null');`), 'rollback;'].join('\n');
  const out = psql(sql).split('\n').filter(l => l.length);
  if (out.length !== ordenes.length) throw new Error(`pedí ${ordenes.length} y contestó ${out.length}`);
  return out.map(l => JSON.parse(l));
}
const j = v => `${dolar(JSON.stringify(v))}::jsonb`;
const sano = (r, que) => { if (r && r.ERROR) throw new Error(`${que}: la base contestó ${r.ERROR}: ${r.message}`); return r; };
// las órdenes que más se repiten
const LEER = { sql: 'select fn_bandeja_leer()' };
const IDS = { sql: `select coalesce(jsonb_agg(b.movimiento_id order by b.fecha, b.movimiento_id), '[]'::jsonb) from v_banco_bandeja b where b.movimiento_id in (select movimiento from public.f19_semilla)` };
const FILAS = { sql: `select coalesce(jsonb_agg(to_jsonb(b) order by b.alarma desc, b.fecha, b.movimiento_id), '[]'::jsonb) from v_banco_bandeja b where b.movimiento_id in (select movimiento from public.f19_semilla)` };
const hacer = (mov, accion, datos, op) => ({ sql: `select fn_bandeja_hacer('${mov}', '${accion}', ${j(datos || {})}, ${j(op || {})})` });
const grupo = (clave, accion, datos, op) => ({ sql: `select fn_bandeja_grupo(${dolar(clave)}, ${accion ? `'${accion}'` : 'null'}, ${j(datos || {})}, ${j(op || {})})` });
// lo que queda de fn_bandeja_leer después de una acción: lo que cambia (lo demás es lo del principio)
const resto = l => { const { version, categorias, cuentas_propias, prestamos, cuadrilla, ...x } = sano(l, 'fn_bandeja_leer'); return x; };

// ---------- 1. armar la base ----------
console.log(`armando ${BD} desde ${PLANTILLA}…`);
su(`drop database if exists ${BD}`);
su(`create database ${BD} template ${PLANTILLA} owner editor_sql`);
su(`grant create on database ${BD} to editor_sql`);
for (const f of CAPAS) pegar(f);
pegar(SEMILLA, false);
console.log('  capas del árbol, c17, c18 y la semilla puestas');

// ---------- 2. lo que la pantalla pide ----------
const ids = Object.fromEntries(psql('select clave, movimiento from public.f19_semilla order by clave').split('\n').filter(Boolean).map(l => l.split('|')));
const propIA = psql(`select id from contador_propuestas where movimiento_id = '${ids.fe1}' and estado = 'pendiente'`).trim();
const anio = Number(psql('select extract(year from fn_fecha_miami(now()))::int').trim());
const [bandeja, leer, facturas, cuentas, proyectos, validar] = pedir([FILAS, LEER, { sql: 'select fn_bandeja_facturas()' },
  { sql: `select jsonb_agg(jsonb_build_object('codigo', c.codigo, 'nombre', c.nombre, 'tipo', c.tipo, 'regla_obra', c.regla_obra) order by c.codigo) from cuentas c where c.imputable and c.activa` },
  { sql: `select jsonb_agg(jsonb_build_object('id', p.id, 'nombre', p.nombre, 'estado', p.estado) order by p.nombre) from proyectos p` },
  { sql: `select fn_bandeja_validar('${ids.hd3}', 'gasto', ${j({ cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' })})` }]).map((r, i) => sano(r, 'lo del principio ' + i));
const rec = k => { const t = leer.tarjetas[ids[k]]; if (!t || !t.rec || !t.rec.accion) throw new Error(`la semilla ya no deja una recomendación para «${k}»: ${JSON.stringify(t)}`); return t.rec; };
const sinRec = k => { const t = leer.tarjetas[ids[k]]; if (!t || (t.rec && t.rec.accion)) throw new Error(`«${k}» no debía traer recomendación: ${JSON.stringify(t)}`); };
// lo que la semilla tiene que dejar (si cambia, las comprobaciones de la pantalla dejarían de valer: falla aquí)
const espera = (k, accion, fuente) => { const r = rec(k); if (r.accion !== accion || (fuente && r.fuente !== fuente)) throw new Error(`«${k}» debía recomendarse como ${accion}${fuente ? ' (' + fuente + ')' : ''} y salió ${r.accion} (${r.fuente})`); };
espera('hd1', 'gasto', 'nombre'); espera('hd3', 'gasto', 'nombre'); espera('nf1', 'personal', 'nombre'); espera('ww1', 'gasto', 'nombre');
espera('od1', 'prestamo', 'app'); espera('in1', 'cobro', 'app'); espera('zl1', 'cobro', 'app'); espera('cu1', 'banco', 'banco'); espera('it1', 'banco', 'banco'); espera('fe1', 'ia', 'ia');
['at1', 'dp1', 'zp1'].forEach(sinRec);
if (rec('hd1').datos.proyecto_id !== 'casa-perez-k3m9' || !rec('hd3').pide_obra) throw new Error('la obra del día no salió como la semilla la monta');
if ((rec('in1').datos.facturas || []).length !== 2 || !rec('in1').datos.comision) throw new Error('el depósito del procesador no salió con sus dos facturas y su comisión');
const gr = c => { const g = (leer.grupos || []).find(x => x.clave === c); if (!g) throw new Error(`falta el grupo ${c}: ${JSON.stringify((leer.grupos || []).map(x => x.clave))}`); return g; };
gr('C:HOME DEPOT'); gr('C:NETFLIX'); gr('M:cuota_prestamo'); gr('M:interes_tarjeta');

// una acción suelta: lo que contesta y cómo queda la Bandeja (en su transacción, que se deshace)
const sueltas = {};
function suelta(clave, firma, orden, pideHecho) {
  const [resp, despues, quedan] = pedir([orden, LEER, IDS]);
  sano(resp, clave);
  if (pideHecho === true && resp.hecho !== true && !(Number(resp.hechos) > 0)) throw new Error(`${clave}: debía registrarse y no: ${JSON.stringify(resp).slice(0, 300)}`);
  if (pideHecho === false && (resp.hecho === true || Number(resp.hechos) > 0)) throw new Error(`${clave}: no debía registrarse y sí`);
  sueltas[clave] = { firma, resp, despues: { ids: sano(quedan, clave), leer: resto(despues) } };
}
const R = { fuente: 'recomendacion', recordar: true };
// (la firma: la función, el movimiento o el grupo, la acción y lo que distingue una llamada de otra; pantalla.js arma la misma)
suelta('asi_wawa', `hacer|${ids.ww1}|gasto||`, hacer(ids.ww1, 'gasto', rec('ww1').datos, R), true);
suelta('asi_hd_dia', `hacer|${ids.hd1}|gasto|casa-perez-k3m9|`, hacer(ids.hd1, 'gasto', rec('hd1').datos, R), true);
suelta('hd_sin_obra', `hacer|${ids.hd3}|gasto||`, hacer(ids.hd3, 'gasto', { cuenta: '5100' }, R), false);
suelta('asi_hd_obra', `hacer|${ids.hd3}|gasto|oficina-nch-7xq2|`, hacer(ids.hd3, 'gasto', { cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' }, R), true);
suelta('asi_netflix', `hacer|${ids.nf1}|personal||`, hacer(ids.nf1, 'personal', rec('nf1').datos, R), true);
suelta('asi_ondeck', `hacer|${ids.od1}|prestamo||`, hacer(ids.od1, 'prestamo', rec('od1').datos, R), true);
suelta('asi_intuit', `hacer|${ids.in1}|cobro||`, hacer(ids.in1, 'cobro', rec('in1').datos, R), true);
suelta('asi_zelle_llc', `hacer|${ids.zl1}|cobro||`, hacer(ids.zl1, 'cobro', rec('zl1').datos, R), true);
suelta('asi_cuota', `hacer|${ids.cu1}|banco||`, hacer(ids.cu1, 'banco', rec('cu1').datos, { fuente: 'recomendacion' }), true);
suelta('mas_parcial', `hacer|${ids.dp1}|cobro||`, hacer(ids.dp1, 'cobro', { facturas: [{ id: '-1900004', monto: '1000.00' }] }, { fuente: 'mas' }), true);
suelta('mas_aporte_sin', `hacer|${ids.at1}|aporte||`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' }, { fuente: 'mas' }), false);
suelta('mas_aporte_con', `hacer|${ids.at1}|aporte||m`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' }, { fuente: 'mas', motivo: 'efectivo mío que metí para cubrir la semana' }), true);
suelta('mas_anticipo', `hacer|${ids.at1}|anticipo|casa-perez-k3m9|`, hacer(ids.at1, 'anticipo', { proyecto_id: 'casa-perez-k3m9' }, { fuente: 'mas' }), true);
const movsDe = c => gr(c).movimientos;
suelta('lote_cuotas', 'grupo|M:cuota_prestamo||', grupo('M:cuota_prestamo', null, {}, { movimientos: movsDe('M:cuota_prestamo') }), true);
suelta('lote_intereses', 'grupo|M:interes_tarjeta||', grupo('M:interes_tarjeta', null, {}, { movimientos: movsDe('M:interes_tarjeta') }), true);
suelta('grupo_hd_dia', 'grupo|C:HOME DEPOT|gasto|', grupo('C:HOME DEPOT', 'gasto', { cuenta: '5100' }, { movimientos: movsDe('C:HOME DEPOT'), recordar: true, solo: false }), true);
suelta('grupo_hd_obra', 'grupo|C:HOME DEPOT|gasto|oficina-nch-7xq2', grupo('C:HOME DEPOT', 'gasto', { cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' }, { movimientos: movsDe('C:HOME DEPOT'), recordar: true, solo: false }), true);
console.log(`  ${Object.keys(sueltas).length} acciones sueltas`);

// LA CADENA de lo que entra solo (una sola transacción: cada paso ve lo del anterior)
const cadena = (() => {
  const PASOS = [
    ['grupo_solo', () => grupo('C:NETFLIX', 'personal', {}, { movimientos: movsDe('C:NETFLIX'), recordar: true, solo: true })],
    ['llega', () => ({ sql: `select pg_temp.llega('nf3', 1, -15.49, 'NETFLIX.COM')`, quien: 'editor' })],
    ['entra_solo', () => ({ sql: `select fn_bandeja_solo(${j({ corrio: 'pantalla' })})` })],
    ['deshacer', null],
    ['ya_no_entra', () => ({ sql: `select fn_bandeja_memoria(${j({ clave: 'C:NETFLIX', solo: false })})` })],
    ['apagar', () => ({ sql: `select fn_bandeja_config(${j({ solo: false })})` })],
    ['olvidar', () => ({ sql: `select fn_bandeja_memoria(${j({ clave: 'C:NETFLIX', activa: false })})` })]];
  // (el paso «deshacer» necesita el registro que dejó «entra_solo»: se saca dentro de la misma transacción)
  const DESHACER = { sql: `select fn_bandeja_deshacer((select h.id from bandeja_hechos h where h.solo and h.deshecho_el is null order by h.el desc limit 1), 'no era mío: fue una compra de la oficina')` };
  const ordenes = [];
  for (const [, f] of PASOS) ordenes.push(f ? f() : DESHACER, LEER, FILAS);
  const out = pedir(ordenes), pasos = [];
  PASOS.forEach(([paso], i) => {
    const resp = sano(out[i * 3], 'cadena ' + paso);
    pasos.push({ paso, resp, despues: { filas: sano(out[i * 3 + 2], paso), leer: resto(out[i * 3 + 1]) } });
  });
  const de = p => pasos.find(x => x.paso === p);
  if (Number(de('grupo_solo').resp.hechos) !== 2 || !(de('grupo_solo').resp.recordado || {}).solo) throw new Error('cadena: el grupo de Netflix no entró con «que lo siguiente entre solo»');
  if ((de('entra_solo').resp.registrados || []).length !== 1) throw new Error('cadena: el cargo que llegó no entró solo: ' + JSON.stringify(de('entra_solo').resp));
  if (de('deshacer').resp.deshecho !== true) throw new Error('cadena: no se deshizo');
  return pasos;
})();
console.log(`  la cadena de lo que entra solo: ${cadena.length} pasos`);

// «DÍMELO»: lo que la base guarda para cada respuesta de la IA (la respuesta va escrita, como la del simulador)
const U = { input: 2400, output: 180, cache_creacion: 0, cache_lectura: 1900 };
const guardar = (mov, frase, respuesta) => ({ quien: 'editor', sql: `select fn_bandeja_dimelo_guardar('${mov}', '${DUENO}', ${dolar(frase)}, false, '{}'::jsonb, '{}'::jsonb, ${j(respuesta)}, 'claude-opus-5-5', 'medium', 'f19-capturar', ${j(U)})` });
const dimelo = {};
{
  // (a) el efectivo del cajero es el adelanto de una obra: se aprueba
  const frase = 'es un adelanto en efectivo de la casa del roble', ia = { accion: 'anticipo', proyecto_id: 'casa-perez-k3m9', recordar: false, explicacion: 'Un adelanto en efectivo del cliente de ZZ Casa Roble, todavía sin factura.' };
  const [g, l1, a, l2, q] = pedir([guardar(ids.at1, frase, ia), LEER,
    { sql: `select fn_bandeja_aprobar((select id from bandeja_dimelo where movimiento_id = '${ids.at1}' and estado = 'pendiente'), ${j({ recordar: false })})` }, LEER, IDS]);
  if (sano(g, 'dimelo anticipo').estado !== 'pendiente' || sano(a, 'aprobar').hecho !== true) throw new Error('dimelo: el anticipo no quedó pendiente o no se aprobó: ' + JSON.stringify([g, a]).slice(0, 400));
  dimelo.anticipo = { movimiento: ids.at1, frase, ia, guardado: g, leer_pendiente: resto(l1), aprobar: { resp: a, despues: { ids: q, leer: resto(l2) } } };
}
{
  // (b) el Zelle a una persona es el pago a un subcontratista de una obra: «No, es otra cosa»
  const frase = 'es el pago al que puso el tile en la oficina', ia = { accion: 'contratista', proyecto_id: 'oficina-nch-7xq2', recordar: true, explicacion: 'El pago a un subcontratista por la obra ZZ Oficina Norte.' };
  const [g, r] = pedir([guardar(ids.zp1, frase, ia), { sql: `select fn_bandeja_rechazar((select id from bandeja_dimelo where movimiento_id = '${ids.zp1}' and estado = 'pendiente'), null)` }]);
  if (sano(g, 'dimelo contratista').estado !== 'pendiente') throw new Error('dimelo: el pago al subcontratista no quedó pendiente');
  dimelo.contratista = { movimiento: ids.zp1, frase, ia, guardado: g, rechazar: sano(r, 'rechazar') };
}
{
  // (c) la IA no lo encuentra: dice qué le falta
  const frase = 'creo que es de una obra pero no me acuerdo', ia = { accion: 'falta', falta: 'No sé de qué obra es: dime el nombre de la obra o del cliente que lo depositó.', explicacion: '' };
  const [g] = pedir([guardar(ids.dp1, frase, ia)]);
  if (sano(g, 'dimelo falta').estado !== 'sin_propuesta') throw new Error('dimelo: «falta» debía quedar sin propuesta');
  dimelo.falta = { movimiento: ids.dp1, frase, ia, guardado: g };
}
{
  // (d) la IA contesta algo que la base no deja pasar (un sueldo a la cuenta de la nómina): la base lo frena
  const frase = 'ponlo como sueldo', ia = { accion: 'gasto', cuenta: '6000', explicacion: 'Sueldos.' };
  const [g] = pedir([guardar(ids.zp1, frase, ia)]);
  if (sano(g, 'dimelo frenado').estado !== 'sin_propuesta') throw new Error('dimelo: una cuenta prohibida debía quedar sin propuesta: ' + JSON.stringify(g));
  dimelo.frenada = { movimiento: ids.zp1, frase, ia, guardado: g };
}
{
  // (e) el tope del mes gastado: ni un token (lo dice el contexto, antes de llamar a la IA; la función de borde lo devuelve tal cual)
  const [, k] = pedir([{ quien: 'editor', sql: `update contador_config set tope_mes_centavos = 0 where id = 1 returning to_jsonb(tope_mes_centavos)` },
    { quien: 'editor', sql: `select fn_bandeja_dimelo_contexto('${ids.at1}', '${DUENO}', 'da igual lo que diga')` }]);
  if (sano(k, 'dimelo bloqueado').bloqueado !== true) throw new Error('dimelo: con el tope gastado el contexto debía decir «bloqueado»: ' + JSON.stringify(k).slice(0, 300));
  dimelo.bloqueado = { movimiento: ids.at1, contexto: { bloqueado: true, motivo: k.motivo, tope: k.tope } };
}
console.log(`  «Dímelo»: ${Object.keys(dimelo).length} casos`);

// la propuesta de la IA (c8) aprobada por su puerta (lo que hace la función de borde «contador» con «aprobar»)
const iaAprobar = (() => {
  const [a, l, q] = pedir([{ quien: 'editor', sql: `select fn_contador_aprobar('${propIA}', '${DUENO}', null, true)` }, LEER, IDS]);
  sano(a, 'fn_contador_aprobar');
  return { propuesta: propIA, movimiento: ids.fe1, resp: a, despues: { ids: q, leer: resto(l) } };
})();

// lo fiscal (c18)
const fiscal = (() => {
  const [l, p] = pedir([{ sql: 'select fn_fiscal_leer()' }, { sql: `select fn_fiscal_paquete(${anio}, null)` }]);
  const [f, l2, p2] = pedir([{ sql: `select fn_fiscal_forma(${j({ forma: '1120-S' })})` }, { sql: 'select fn_fiscal_leer()' }, { sql: `select fn_fiscal_paquete(${anio}, null)` }]);
  const [c, l3, p3] = pedir([{ sql: `select fn_fiscal_forma(${j({ confirmada: true })})` }, { sql: 'select fn_fiscal_leer()' }, { sql: `select fn_fiscal_paquete(${anio}, null)` }]);
  [l, p, f, l2, p2, c, l3, p3].forEach((x, i) => sano(x, 'fiscal ' + i));
  if (!(p.warnings || []).some(w => /PENDING CONFIRMATION/.test(w)) || (p3.warnings || []).some(w => /PENDING CONFIRMATION/.test(w))) throw new Error('fiscal: el aviso de «pendiente de confirmar» no sale (o no se quita al confirmar)');
  if (p2.entity.form !== '1120-S') throw new Error('fiscal: el paquete no cambió al 1120-S');
  return { anio, leer: l, paquete: p, a_1120s: { resp: f, leer: l2, paquete: p2 }, confirmada: { resp: c, leer: l3, paquete: p3 } };
})();
console.log('  lo fiscal: el paquete con el 1120, con el 1120-S y confirmado');

// ---------- 3. que no salga nada de verdad ----------
const out = {
  que: 'La base simulada de la Bandeja nueva (c17) y de las cuentas en inglés (c18), sacada del banco de pruebas por pruebas/conta/f19-capturar.js: cada respuesta es la que dio la base, como el dueño.',
  capturado: psql('select fn_fecha_miami(now())').trim(), plantilla: PLANTILLA,
  huellas: { 'docs/conta/c17-bandeja.sql': huella('docs/conta/c17-bandeja.sql'), 'docs/conta/c18-fiscal.sql': huella('docs/conta/c18-fiscal.sql'), [SEMILLA]: huella(SEMILLA) },
  dueno: DUENO, ids, propuesta_ia: propIA, cuentas, proyectos, bandeja, leer, facturas, validar, sueltas, cadena, dimelo, ia_aprobar: iaAprobar, fiscal
};
const texto = JSON.stringify(out, null, 1);
const sinIds = texto.replace(/casa-perez-k3m9|oficina-nch-7xq2|taller-ruiz-5b2n/g, '');
const malo = /p[eé]rez|\bnch\b|ruiz|gustavo|\bpedro\b|edgar@|@(?!example\.com)[a-z0-9-]+\.(com|net|org)/i.exec(sinIds);
if (malo) throw new Error(`en lo capturado sale «${malo[0]}»: la semilla tiene que dejarlo todo «ZZ» (${sinIds.slice(Math.max(0, malo.index - 80), malo.index + 80)})`);
fs.writeFileSync(SALIDA, texto + '\n');
console.log(`escrito ${path.relative(ROOT, SALIDA)} (${Math.round(texto.length / 1024)} KB): ${bandeja.length} movimientos, ${Object.keys(sueltas).length} acciones sueltas, ${cadena.length} pasos de la cadena, ${Object.keys(dimelo).length} del «Dímelo»`);
