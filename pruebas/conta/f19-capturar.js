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
        (segunda vuelta) y LOS GUIONES, cada uno en UNA transacción, paso a
        paso como los daría la pantalla: el recibo que llega después de
        registrar su cargo (uno se cambia solo; de dos cargos iguales, «es
        otra compra» con el freno y su porqué, y «es su recibo»), una
        decisión por grupo que se deshace entera (su tanda), lo ya
        contestado que se toca otra vez («fuera»), el freno del banco con su
        huella (por «Más opciones» y por el «Dímelo»), el pago a la
        cuadrilla que c10 apunta y no registra («dicho»), una propuesta que
        ya no está pendiente (MX008), el paquete de un año que la app no
        lleva, y los nombres en inglés que traen las vistas de los estados;
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
create or replace function pg_temp.pedir(p_sql text, p_quien text default 'dueno') returns jsonb language plpgsql as $f$
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
end $f$;
-- (segunda vuelta) UN GUION: varios pasos seguidos en la misma transacción, cada uno con lo que contesta la base y cómo queda la
-- Bandeja después (lo que lee la pantalla, los movimientos que siguen esperando y si el control del banco dice que hay un gasto dos
-- veces por un recibo que llegó después)
create temp table _guion (n serial, paso text, resp jsonb, leer jsonb, ids jsonb, rojo57 text) on commit drop;
create or replace function pg_temp.paso(p_nombre text, p_sql text, p_quien text default 'dueno') returns jsonb language plpgsql as $f$
declare r jsonb; l jsonb; i jsonb; k text;
begin
  r := pg_temp.pedir(p_sql, p_quien);
  l := pg_temp.pedir('select fn_bandeja_leer()', 'dueno');
  i := pg_temp.pedir($q$select coalesce(jsonb_agg(b.movimiento_id order by b.fecha, b.movimiento_id), '[]'::jsonb) from v_banco_bandeja b where b.movimiento_id in (select movimiento from public.f19_semilla)$q$, 'dueno');
  k := pg_temp.pedir($q$select to_jsonb((select x.detalle from fn_banco_control('hoy', array['v_banco_bandeja']) x where x.vista = 'cuadre: ningún ticket después de clasificar' and not x.ok))$q$, 'dueno') #>> '{}';
  insert into _guion (paso, resp, leer, ids, rojo57) values (p_nombre, r, l, i, k);
  return r;
end $f$;
create or replace function pg_temp.mov(k text) returns uuid language sql as $f$ select movimiento from public.f19_semilla where clave = k $f$;`;
function pedir(ordenes) {
  const sql = ['begin;', AYUDA, ...ordenes.map(o => `select coalesce(pg_temp.pedir(${dolar(o.sql)}, '${o.quien || 'dueno'}')::text, 'null');`), 'rollback;'].join('\n');
  const out = psql(sql).split('\n').filter(l => l.length);
  if (out.length !== ordenes.length) throw new Error(`pedí ${ordenes.length} y contestó ${out.length}`);
  return out.map(l => JSON.parse(l));
}
// un guion: el cuerpo es plpgsql (declarados: r, r2 jsonb; t text) que va llamando a pg_temp.paso(nombre, sql[, quien]); devuelve
// [{paso, resp, despues: {ids, leer, rojo57}}]
function guion(nombre, cuerpo) {
  const sql = ['begin;', AYUDA, `do $g$\ndeclare r jsonb; r2 jsonb; t text;\nbegin\n${cuerpo}\nend $g$;`,
    `select coalesce(jsonb_agg(jsonb_build_object('paso', paso, 'resp', resp, 'leer', leer, 'ids', ids, 'rojo57', rojo57) order by n), '[]'::jsonb)::text from _guion;`, 'rollback;'].join('\n');
  const out = psql(sql).split('\n').filter(l => l.length);
  const pasos = JSON.parse(out[out.length - 1]);
  if (!pasos.length) throw new Error(`guion ${nombre}: no dejó ningún paso`);
  return pasos.map(p => { if (p.resp && p.resp.ERROR && !/^MX/.test(p.resp.ERROR)) throw new Error(`guion ${nombre}, ${p.paso}: ${p.resp.ERROR}: ${p.resp.message}`);
    return { paso: p.paso, resp: p.resp, despues: { ids: p.ids, leer: resto(p.leer), rojo57: p.rojo57 } }; });
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
// (ni lo fijo, ni lo que quedó igual que al principio: pantalla.js lo pone encima de la lectura del principio)
let LEER0 = null;
const resto = l => { const { version, categorias, cuentas_propias, prestamos, cuadrilla, proveedores, ...x } = sano(l, 'fn_bandeja_leer');
  if (LEER0) for (const k of Object.keys(x)) if (JSON.stringify(x[k]) === JSON.stringify(LEER0[k])) delete x[k];
  return x; };

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
LEER0 = leer;
const rec = k => { const t = leer.tarjetas[ids[k]]; if (!t || !t.rec || !t.rec.accion) throw new Error(`la semilla ya no deja una recomendación para «${k}»: ${JSON.stringify(t)}`); return t.rec; };
const sinRec = k => { const t = leer.tarjetas[ids[k]]; if (!t || (t.rec && t.rec.accion)) throw new Error(`«${k}» no debía traer recomendación: ${JSON.stringify(t)}`); };
// lo que la semilla tiene que dejar (si cambia, las comprobaciones de la pantalla dejarían de valer: falla aquí)
const espera = (k, accion, fuente) => { const r = rec(k); if (r.accion !== accion || (fuente && r.fuente !== fuente)) throw new Error(`«${k}» debía recomendarse como ${accion}${fuente ? ' (' + fuente + ')' : ''} y salió ${r.accion} (${r.fuente})`); };
espera('hd1', 'gasto', 'nombre'); espera('hd3', 'gasto', 'nombre'); espera('nf1', 'personal', 'nombre'); espera('ww1', 'gasto', 'nombre');
espera('od1', 'prestamo', 'app'); espera('in1', 'cobro', 'app'); espera('zl1', 'cobro', 'app'); espera('cu1', 'banco', 'banco'); espera('it1', 'banco', 'banco'); espera('fe1', 'ia', 'ia');
// (segunda vuelta) el pago de la tarjeta lo reconoce el banco; la comisión del procesador y QuickBooks, cada uno lo suyo; el
// permiso y la luz de la ciudad, también
espera('tj1', 'banco', 'banco'); espera('if1', 'gasto', 'app'); espera('iq1', 'gasto', 'nombre'); espera('co1', 'gasto', 'nombre'); espera('co2', 'gasto', 'nombre');
['at1', 'dp1', 'zp1', 'in2', 'tr1', 'rc1', 'rc2', 'rc3'].forEach(sinRec);
if (rec('tj1').datos.llamar !== 'fn_banco_transferencia' || !rec('tj1').datos.huella || /\d{4}-\d{4}/.test(rec('tj1').texto)) throw new Error('el pago de la tarjeta no salió en llano, por la puerta de las transferencias y con su huella: ' + JSON.stringify(rec('tj1')));
if (rec('co1').datos.cuenta === rec('co2').datos.cuenta) throw new Error('el permiso y la luz de la ciudad debían recomendarse distinto');
if (rec('if1').datos.cuenta === rec('iq1').datos.cuenta || leer.tarjetas[ids.if1].clave === leer.tarjetas[ids.iq1].clave) throw new Error('la comisión del procesador y la suscripción de QuickBooks debían ir cada una por su lado');
if (!(leer.proveedores || []).length) throw new Error('la semilla debía dejar un subcontratista dado de alta');
if (rec('hd1').datos.proyecto_id !== 'casa-perez-k3m9' || !rec('hd3').pide_obra) throw new Error('la obra del día no salió como la semilla la monta');
if ((rec('in1').datos.facturas || []).length !== 2 || !rec('in1').datos.comision) throw new Error('el depósito del procesador no salió con sus dos facturas y su comisión');
const gr = c => { const g = (leer.grupos || []).find(x => x.clave === c); if (!g) throw new Error(`falta el grupo ${c}: ${JSON.stringify((leer.grupos || []).map(x => x.clave))}`); return g; };
gr('C:HOME DEPOT'); gr('C:NETFLIX'); gr('M:cuota_prestamo'); gr('M:interes_tarjeta');
// (segunda vuelta) los grupos son de CARGOS y dicen lo que sus tarjetas: el de la ciudad está mezclado (no propone nada), el de la
// maderera no se sabe, y los depósitos del procesador van juntos pero de uno en uno
if (!gr('C:HOME DEPOT').rec || gr('C:HOME DEPOT').rec.accion !== 'gasto' || !gr('C:NETFLIX').rec || gr('C:NETFLIX').rec.accion !== 'personal') throw new Error('los grupos de Home Depot y de Netflix debían traer la recomendación de sus tarjetas');
if (!gr('C:CITY OF OCALA').mixto || gr('C:CITY OF OCALA').rec) throw new Error('el grupo de la ciudad debía salir mezclado y sin recomendación');
if (gr('C:ZZ MADERAS DEL SUR').rec || gr('C:ZZ MADERAS DEL SUR').mixto) throw new Error('el grupo de la maderera debía salir sin decidir');
if (!gr('P:INTUIT').uno_a_uno || gr('P:INTUIT').rec) throw new Error('los depósitos del procesador debían ir juntos pero de uno en uno');
if ((leer.grupos || []).length !== 7 || (leer.control || []).length) throw new Error(`se esperaban 7 grupos y ningún aviso del control: ${JSON.stringify((leer.grupos || []).map(x => x.clave))} · ${JSON.stringify(leer.control)}`);

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
// (segunda vuelta) el banco cree que ese depósito lo explica una factura: la línea que Edgar escribe («de dónde salió») NO apaga ese
// freno; la puerta lo dice y pide su porqué, y solo con él (y la huella de ese freno) entra
suelta('mas_aporte_con', `hacer|${ids.at1}|aporte||m`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' }, { fuente: 'mas', motivo: 'efectivo mío que metí para cubrir la semana' }), false);
if (!sueltas.mas_aporte_con.resp.freno || sueltas.mas_aporte_con.resp.pide_motivo !== true) throw new Error('el dinero del dueño en un depósito que el banco cree de una factura debía frenar con su huella: ' + JSON.stringify(sueltas.mas_aporte_con.resp));
suelta('mas_aporte_visto', `hacer|${ids.at1}|aporte||mv`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' },
  { fuente: 'mas', motivo: 'efectivo mío que metí para cubrir la semana. no es de ningún cliente: lo saqué de mi cuenta', visto: sueltas.mas_aporte_con.resp.freno }), true);
suelta('mas_anticipo', `hacer|${ids.at1}|anticipo|casa-perez-k3m9|`, hacer(ids.at1, 'anticipo', { proyecto_id: 'casa-perez-k3m9' }, { fuente: 'mas' }), true);
// (segunda vuelta) lo que el banco ya reconoce, en llano: el pago de la tarjeta
suelta('asi_tarjeta', `hacer|${ids.tj1}|banco||`, hacer(ids.tj1, 'banco', rec('tj1').datos, { fuente: 'recomendacion' }), true);
// EL FRENO DEL BANCO y su huella: «entre mis cuentas» en algo que el banco no reconoce como traspaso. Sin porqué, la puerta frena y
// lo dice; un porqué SIN la huella de ese freno no lo levanta; con ella, entra
suelta('mas_traspaso_freno', `hacer|${ids.tr1}|traspaso||`, hacer(ids.tr1, 'traspaso', { cuenta: '1030' }, { fuente: 'mas', recordar: true }), false);
if (!sueltas.mas_traspaso_freno.resp.freno || sueltas.mas_traspaso_freno.resp.pide_motivo !== true) throw new Error('el traspaso que el banco no reconoce debía frenar con su huella: ' + JSON.stringify(sueltas.mas_traspaso_freno.resp));
suelta('mas_traspaso_sin_ver', `hacer|${ids.tr1}|traspaso||m`, hacer(ids.tr1, 'traspaso', { cuenta: '1030' }, { fuente: 'mas', recordar: true, motivo: 'lo pasé a la reserva de impuestos' }), false);
suelta('mas_traspaso_visto', `hacer|${ids.tr1}|traspaso||mv`, hacer(ids.tr1, 'traspaso', { cuenta: '1030' }, { fuente: 'mas', recordar: true, motivo: 'lo pasé a la reserva de impuestos', visto: sueltas.mas_traspaso_freno.resp.freno }), true);
// EL PAGO A LA CUADRILLA que c10 apunta y no registra (avisa de algo): «dicho»; la tarjeta pasa a ser la de la mano de obra
suelta('mas_cuadrilla', `hacer|${ids.zp1}|cuadrilla||`, hacer(ids.zp1, 'cuadrilla', { usuario_id: '00000000-0000-4000-a000-000000000002' }, { fuente: 'mas', recordar: true }), false);
if (sueltas.mas_cuadrilla.resp.dicho !== true) throw new Error('el pago a la cuadrilla debía quedar «dicho» (apuntado, sin registrar): ' + JSON.stringify(sueltas.mas_cuadrilla.resp));
// el pago a un subcontratista, con su nombre
suelta('mas_contratista', `hacer|${ids.zp1}|contratista|oficina-nch-7xq2|`, hacer(ids.zp1, 'contratista', { proyecto_id: 'oficina-nch-7xq2', proveedor_id: leer.proveedores[0].proveedor_id }, { fuente: 'mas', recordar: true }), true);
// el préstamo sin dar de alta: registrado, el control de la Bandeja lo dice (en llano) en lo que lee la pantalla
if (!((sueltas.asi_ondeck.despues.leer.control || []).some(k => Number(k.orden) === 70))) throw new Error('tras registrar el préstamo sin alta, la lectura debía traer el aviso 70 del control: ' + JSON.stringify(sueltas.asi_ondeck.despues.leer.control));
const movsDe = c => gr(c).movimientos;
suelta('lote_cuotas', 'grupo|M:cuota_prestamo||', grupo('M:cuota_prestamo', null, {}, { movimientos: movsDe('M:cuota_prestamo') }), true);
suelta('lote_intereses', 'grupo|M:interes_tarjeta||', grupo('M:interes_tarjeta', null, {}, { movimientos: movsDe('M:interes_tarjeta') }), true);
suelta('grupo_hd_dia', 'grupo|C:HOME DEPOT|gasto|', grupo('C:HOME DEPOT', 'gasto', { cuenta: '5100' }, { movimientos: movsDe('C:HOME DEPOT'), recordar: true, solo: false }), true);
suelta('grupo_hd_obra', 'grupo|C:HOME DEPOT|gasto|oficina-nch-7xq2', grupo('C:HOME DEPOT', 'gasto', { cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' }, { movimientos: movsDe('C:HOME DEPOT'), recordar: true, solo: false }), true);
// (segunda vuelta) los depósitos NO se deciden por grupo: la base lo rechaza con su regla (MX008), dicho en llano
const grupoDep = pedir([grupo('P:INTUIT', 'anticipo', { proyecto_id: 'casa-perez-k3m9' }, { movimientos: movsDe('P:INTUIT') })])[0];
if (!grupoDep || grupoDep.ERROR !== 'MX008') throw new Error('decidir por grupo los depósitos del procesador debía rechazarse con MX008: ' + JSON.stringify(grupoDep));
console.log(`  ${Object.keys(sueltas).length} acciones sueltas`);

// LOS GUIONES (segunda vuelta): varios pasos en una transacción
const guiones = {};
// EL RECIBO QUE LLEGA DESPUÉS. Tres compras con la tarjeta de obra se registran desde la Bandeja (a ZZ Oficina Norte) y DESPUÉS la
// cuadrilla sube sus recibos (a ZZ Casa Roble): el de la compra suelta se cambia solo; el de las dos compras iguales no se sabe de
// cuál es: la Bandeja enseña las dos, cada una con «es su recibo» y «es otra compra»
guiones.recibos = guion('recibos', `
  perform pg_temp.pedir(format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"5100","proyecto_id":"oficina-nch-7xq2"}', '{"fuente":"mas"}')$q$, pg_temp.mov(k))) from unnest(array['rc1','rc2','rc3']) k;
  insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago, ultimos4)
  overriding system value values
    (-1900021, 'casa-perez-k3m9', 'recibos/f19/1900021.jpg', 64.37, 'ZZ MADERAS DEL SUR', 'f19-capturar', 'leido', '${DUENO}', now(), fn_fecha_miami(now()) - 5, 'material', 'ZZ19-R1', 'credito', '9919'),
    (-1900023, 'casa-perez-k3m9', 'recibos/f19/1900023.jpg', 77.31, 'ZZ ELECTRICA TOTAL', 'f19-capturar', 'leido', '${DUENO}', now(), fn_fecha_miami(now()) - 4, 'material', 'ZZ19-R3', 'credito', '9919');
  perform fn_puentes_correr();
  perform pg_temp.paso('inicio', 'select null::jsonb');
  perform pg_temp.paso('solo', $q$select fn_bandeja_solo('{"corrio":"pantalla"}')$q$);
  r := pg_temp.paso('otra_freno', $q$select fn_bandeja_hacer((fn_bandeja_leer()->'recibos'->0->>'movimiento_id')::uuid, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'recibos'->0->'opciones') o where o->>'es' = 'otra'),
         '{"fuente":"mas"}')$q$);
  perform pg_temp.paso('otra_visto', format($q$select fn_bandeja_hacer(%L, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'recibos'->0->'opciones') o where o->>'es' = 'otra'), %L)$q$,
         r->>'movimiento_id', jsonb_build_object('fuente', 'mas', 'motivo', 'fueron dos compras iguales el mismo día', 'visto', r->>'freno')));
  perform pg_temp.paso('recibo', $q$select fn_bandeja_hacer((fn_bandeja_leer()->'recibos'->0->>'movimiento_id')::uuid, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'recibos'->0->'opciones') o where o->>'es' = 'recibo'),
         '{"fuente":"mas"}')$q$);`);
{
  const g = Object.fromEntries(guiones.recibos.map(p => [p.paso, p])), rs = p => (g[p].despues.leer.recibos || LEER0.recibos || []);
  if (!g.inicio.despues.rojo57 || rs('inicio').length) throw new Error('guion recibos: al principio el control debía decir que hay un gasto dos veces y la Bandeja todavía no saberlo');
  if ((g.solo.resp.recibos.cambiados || []).length !== 1 || g.solo.resp.recibos.esperan !== 2 || rs('solo').length !== 2 || !g.solo.despues.rojo57) throw new Error('guion recibos: la rutina debía cambiar uno y dejar dos esperando: ' + JSON.stringify(g.solo.resp));
  if (g.otra_freno.resp.hecho !== false || !g.otra_freno.resp.freno || g.otra_visto.resp.hecho !== true || rs('otra_visto').length !== 1) throw new Error('guion recibos: «es otra compra» debía frenar y, con su porqué leído, quedar: ' + JSON.stringify([g.otra_freno.resp, g.otra_visto.resp]).slice(0, 500));
  if (g.recibo.resp.hecho !== true || rs('recibo').length || g.recibo.despues.rojo57) throw new Error('guion recibos: «es su recibo» debía cambiarlo y dejar el banco en verde: ' + JSON.stringify(g.recibo.resp).slice(0, 300));
}
// UNA DECISIÓN POR GRUPO QUE SE DESHACE ENTERA (su tanda)
guiones.tanda = guion('tanda', `
  r := pg_temp.paso('grupo', format($q$select fn_bandeja_grupo('C:HOME DEPOT', 'gasto', '{"cuenta":"5100","proyecto_id":"oficina-nch-7xq2"}', %L)$q$,
         jsonb_build_object('movimientos', (select jsonb_agg(pg_temp.mov(k)) from unnest(array['hd1','hd2','hd3']) k), 'recordar', true, 'solo', false)));
  perform pg_temp.paso('deshacer_tanda', format($q$select fn_bandeja_deshacer_tanda(%L, 'me equivoqué de obra')$q$, r->>'tanda'));`);
{
  const [a, b] = guiones.tanda;
  if (Number(a.resp.hechos) !== 3 || !a.resp.tanda || (a.despues.leer.tandas || []).length !== 1 || Number(a.despues.leer.tandas[0].n) !== 3) throw new Error('guion tanda: el grupo debía registrar los tres con su tanda: ' + JSON.stringify(a.resp).slice(0, 300));
  if (Number(b.resp.deshechos) !== 3 || (b.despues.leer.tandas || LEER0.tandas || []).length) throw new Error('guion tanda: deshacer la tanda debía devolver los tres: ' + JSON.stringify(b.resp));
}
// LO YA CONTESTADO, TOCADO OTRA VEZ (otra pestaña, o la contestación que se perdió): «fuera»
guiones.fuera = guion('fuera', `
  perform pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"6300"}', '{"fuente":"recomendacion","recordar":true}')$q$, pg_temp.mov('ww1')));
  perform pg_temp.paso('otra_vez', format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"6300"}', '{"fuente":"recomendacion","recordar":true}')$q$, pg_temp.mov('ww1')));`);
if (guiones.fuera[0].resp.hecho !== true || guiones.fuera[1].resp.fuera !== true) throw new Error('guion fuera: la segunda vez debía decir «fuera»: ' + JSON.stringify(guiones.fuera[1].resp));
console.log(`  ${Object.keys(guiones).length} guiones: ${Object.entries(guiones).map(([k, v]) => `${k} (${v.length})`).join(', ')}`);

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
// (como la función de borde: lo que guarda lleva lo que se le enseñó a la IA de ese movimiento —el contexto de verdad—, que es con lo
// que la base comprueba una opción del banco)
const guardarSql = (mov, frase, respuesta) => `select fn_bandeja_dimelo_guardar('${mov}', '${DUENO}', ${dolar(frase)}, false,
  (select jsonb_build_object('movimiento', k->'movimiento', 'lo_que_dice_edgar', k->'frase') from (select fn_bandeja_dimelo_contexto('${mov}', '${DUENO}', ${dolar(frase)}) as k) z),
  '{}'::jsonb, ${j(respuesta)}, 'claude-opus-5-5', 'medium', 'f19-capturar', ${j(U)})`;
const guardar = (mov, frase, respuesta) => ({ quien: 'editor', sql: guardarSql(mov, frase, respuesta) });
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
  // (y, rechazada —desde otra pestaña, por ejemplo—, su «Así es» ya no vale: la base lo dice con su regla, MX008)
  const [g, r, tarde] = pedir([guardar(ids.zp1, frase, ia), { sql: `select fn_bandeja_rechazar((select id from bandeja_dimelo where movimiento_id = '${ids.zp1}' and estado = 'pendiente'), null)` },
    { sql: `select fn_bandeja_aprobar((select id from bandeja_dimelo where movimiento_id = '${ids.zp1}' order by creado_el desc limit 1), '{}'::jsonb)` }]);
  if (sano(g, 'dimelo contratista').estado !== 'pendiente') throw new Error('dimelo: el pago al subcontratista no quedó pendiente');
  if (!tarde || tarde.ERROR !== 'MX008') throw new Error('dimelo: aprobar una propuesta ya rechazada debía dar MX008: ' + JSON.stringify(tarde));
  dimelo.contratista = { movimiento: ids.zp1, frase, ia, guardado: g, rechazar: sano(r, 'rechazar'), aprobar_tarde: tarde };
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
{
  // (f) EL FRENO DEL BANCO TAMBIÉN POR EL «DÍMELO»: la frase de Edgar no es un motivo. La IA entiende «entre mis cuentas» en algo que
  // el banco no reconoce como traspaso: «Así es» frena y dice por qué; con su porqué escrito DESPUÉS de leerlo (su huella), entra
  const frase = 'lo pasé a la cuenta de la reserva de impuestos', ia = { accion: 'traspaso', cuenta_destino: '1030', recordar: false, explicacion: 'Dinero que pasaste del banco operativo a la reserva de impuestos.' };
  const pasos = guion('dimelo_freno', `
    r := pg_temp.paso('guardar', ${dolar(guardarSql(ids.tr1, frase, ia))}, 'editor');
    r2 := pg_temp.paso('aprobar_freno', format($q$select fn_bandeja_aprobar(%L, '{}'::jsonb)$q$, r->>'dimelo_id'));
    perform pg_temp.paso('aprobar_visto', format($q$select fn_bandeja_aprobar(%L, %L)$q$, r->>'dimelo_id',
              jsonb_build_object('motivo', 'es el apartado de los impuestos del trimestre', 'visto', r2->>'freno')));`);
  const [g, fr, ap] = pasos;
  if (g.resp.estado !== 'pendiente' || g.resp.accion !== 'traspaso') throw new Error('dimelo: el traspaso no quedó pendiente: ' + JSON.stringify(g.resp).slice(0, 300));
  if (fr.resp.hecho !== false || !fr.resp.freno || fr.resp.pide_motivo !== true || ap.resp.hecho !== true) throw new Error('dimelo: el «Así es» debía frenar y, con su porqué leído, entrar: ' + JSON.stringify([fr.resp, ap.resp]).slice(0, 500));
  dimelo.traspaso = { movimiento: ids.tr1, frase, ia, guardado: g.resp, aprobar_freno: fr.resp, aprobar: { resp: ap.resp, despues: ap.despues } };
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
  // (segunda vuelta) el año que la app lleva a medias lo dice (el libro del banco empieza dentro del año); el de antes del libro
  // sale vacío y lo dice; y los nombres en inglés que traen las vistas de los estados (para el balance y el flujo de la pantalla)
  const [pf, etq] = pedir([{ sql: `select fn_fiscal_paquete(${anio - 1}, null)` },
    { sql: `select jsonb_object_agg(x.es, x.en) from (
              select distinct etiqueta_es as es, etiqueta_en as en from v_balance_general where periodo = '${anio}' and etiqueta_en is not null and etiqueta_en <> etiqueta_es
              union select distinct etiqueta_es, etiqueta_en from v_flujo_caja where periodo = '${anio}' and etiqueta_en is not null and etiqueta_en <> etiqueta_es
              union select distinct etiqueta_es, etiqueta_en from v_resultados where periodo = '${anio}' and etiqueta_en is not null and etiqueta_en <> etiqueta_es) x` }]);
  sano(pf, 'fiscal fuera'); sano(etq, 'fiscal etiquetas');
  if (p.partial_year !== true || !/^PARTIAL YEAR/.test((p.warnings || [])[0] || '') || /Year-End/.test(p.title)) throw new Error('fiscal: el año que el libro empieza a medias debía salir como parcial, dicho arriba: ' + JSON.stringify([p.title, (p.warnings || [])[0]]));
  if (pf.in_books !== false || !/^NO BOOKS FOR/.test((pf.warnings || [])[0] || '')) throw new Error('fiscal: el año de antes del libro debía salir vacío y dicho: ' + JSON.stringify([pf.title, (pf.warnings || [])[0]]));
  if (!p.retained_earnings || !(p.retained_earnings.rows || []).length || !p.schedule_l || p.schedule_l.balanced !== true) throw new Error('fiscal: el paquete debía traer las utilidades retenidas y el Schedule L cuadrado');
  if (!etq || Object.keys(etq).length < 5) throw new Error('fiscal: las vistas de los estados debían traer sus nombres en inglés: ' + JSON.stringify(etq));
  return { anio, leer: l, paquete: p, a_1120s: { resp: f, leer: l2, paquete: p2 }, confirmada: { resp: c, leer: l3, paquete: p3 }, fuera: { anio: anio - 1, paquete: pf }, etiquetas: etq };
})();
console.log('  lo fiscal: el paquete con el 1120, con el 1120-S y confirmado');

// ---------- 3. que no salga nada de verdad ----------
const out = {
  que: 'La base simulada de la Bandeja nueva (c17) y de las cuentas en inglés (c18), sacada del banco de pruebas por pruebas/conta/f19-capturar.js: cada respuesta es la que dio la base, como el dueño.',
  capturado: psql('select fn_fecha_miami(now())').trim(), plantilla: PLANTILLA,
  huellas: { 'docs/conta/c17-bandeja.sql': huella('docs/conta/c17-bandeja.sql'), 'docs/conta/c18-fiscal.sql': huella('docs/conta/c18-fiscal.sql'), [SEMILLA]: huella(SEMILLA) },
  dueno: DUENO, ids, propuesta_ia: propIA, cuentas, proyectos, bandeja, leer, facturas, validar, sueltas, grupo_depositos: grupoDep, guiones, cadena, dimelo, ia_aprobar: iaAprobar, fiscal
};
const texto = JSON.stringify(out, null, 1);
const sinIds = texto.replace(/casa-perez-k3m9|oficina-nch-7xq2|taller-ruiz-5b2n/g, '');
const malo = /p[eé]rez|\bnch\b|ruiz|gustavo|\bpedro\b|edgar@|@(?!example\.com)[a-z0-9-]+\.(com|net|org)/i.exec(sinIds);
if (malo) throw new Error(`en lo capturado sale «${malo[0]}»: la semilla tiene que dejarlo todo «ZZ» (${sinIds.slice(Math.max(0, malo.index - 80), malo.index + 80)})`);
fs.writeFileSync(SALIDA, texto + '\n');
console.log(`escrito ${path.relative(ROOT, SALIDA)} (${Math.round(texto.length / 1024)} KB): ${bandeja.length} movimientos, ${Object.keys(sueltas).length} acciones sueltas, ${Object.keys(guiones).length} guiones, ${cadena.length} pasos de la cadena, ${Object.keys(dimelo).length} del «Dímelo»`);
