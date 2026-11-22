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
        registrar su cargo (ninguno se cambia solo: los tres esperan arriba;
        de dos cargos iguales, «es otra compra» con el freno y su porqué, y
        «es su recibo»), una
        decisión por grupo que se deshace entera (su tanda), lo ya
        contestado que se toca otra vez («fuera»), el freno del banco con su
        huella (por «Más opciones» y por el «Dímelo»), el pago a la
        cuadrilla que c10 apunta y no registra («dicho»), una propuesta que
        ya no está pendiente (MX008), el paquete de un año que la app no
        lleva, y los nombres en inglés que traen las vistas de los estados;
        (tercera vuelta) LA LECTURA POR PARTES: la Bandeja leída con el reloj
        corto (lo que no dio tiempo vuelve en «faltan», con su tarjeta
        «pensando») y las partes que la pantalla pide después; en cada acción
        suelta, que lo que la base contesta a {ids: los hermanos de lo
        contestado} es lo que f19-parte.js saca de la lectura entera (con eso
        contesta pantalla.js las lecturas por partes); las tres propuestas de
        la IA de antes (c8) aprobadas por su puerta y ANOTADAS por la Bandeja
        (un gasto, algo personal y un gasto de obra con su obra); deshacer
        una decisión por grupo que dejó «que entre solo» (se apaga, o no, si
        Edgar lo dice) y que el cargo siguiente espera; y la tarifa de un
        procesador que se olvida;
        (cuarta vuelta) seis guiones más —el recibo que llega después EN EL
        OTRO ORDEN («es su recibo» en la primera de dos compras iguales: la
        otra deja de esperar); el pago de la tarjeta con UNA SEGUNDA TARJETA
        del mismo banco dada de alta (la tarjeta pregunta cuál: «elige»); un
        botón de «Lo que dice el banco» validado y registrado POR LA BANDEJA
        (el Zelle que paga entera una factura sin marcar: queda cobrada en
        Proyectos); deshacer para corregir (lo deshecho no se propone otra
        vez) y deshacer olvidando lo recordado; y el depósito y el cargo de
        un PRESTAMISTA (el cargo, registrado como un gasto, frena)—; un guion
        puede cambiar la fila de un movimiento que ya esperaba, así que con
        «conFilas» cada paso guarda las filas de la Bandeja que son nuevas o
        distintas de las del principio; lo registrado por el camino de antes
        («Otra cosa…») y ANOTADO después por la Bandeja (fuente «mas»), y
        deshecho; y el paquete del AÑO SIGUIENTE (la balanza con el renglón
        del resultado de años anteriores y sus totales en cero);
        (sexta vuelta, 6b) y el guion de LA LÍNEA DE CRÉDITO: se da de alta
        una línea de un prestamista inventado y llegan dos pagos y un
        desembolso; el primer pago se registra con sus intereses y el segundo
        por el «Dímelo» (lo que la base guarda dice qué pide, y se aprueba
        con ellos);
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
const { parteDe, comparable } = require('./f19-parte.js');

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
             'descripcion', p_desc, 'tipo', case when p_monto > 0 then 'CREDIT' else 'DEBIT' end, 'pendiente', false))));
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
create temp table _guion (n serial, paso text, resp jsonb, leer jsonb, ids jsonb, rojo57 text, filas jsonb) on commit drop;
create or replace function pg_temp.paso(p_nombre text, p_sql text, p_quien text default 'dueno') returns jsonb language plpgsql as $f$
declare r jsonb; l jsonb; i jsonb; k text; f jsonb;
begin
  r := pg_temp.pedir(p_sql, p_quien);
  l := pg_temp.pedir('select fn_bandeja_leer()', 'dueno');
  i := pg_temp.pedir($q$select coalesce(jsonb_agg(b.movimiento_id order by b.fecha, b.movimiento_id), '[]'::jsonb) from v_banco_bandeja b where b.movimiento_id in (select movimiento from public.f19_semilla)$q$, 'dueno');
  k := pg_temp.pedir($q$select to_jsonb((select x.detalle from fn_banco_control('hoy', array['v_banco_bandeja']) x where x.vista = 'cuadre: ningún ticket después de clasificar' and not x.ok))$q$, 'dueno') #>> '{}';
  -- (cuarta vuelta) las filas de la Bandeja de ese momento: un guion puede cambiar lo que el banco propone para un movimiento que
  -- ya esperaba (con una segunda tarjeta dada de alta, el pago de la tarjeta pasa a tener tres opciones)
  f := pg_temp.pedir($q$select coalesce(jsonb_agg(to_jsonb(b) order by b.alarma desc, b.fecha, b.movimiento_id), '[]'::jsonb) from v_banco_bandeja b where b.movimiento_id in (select movimiento from public.f19_semilla)$q$, 'dueno');
  insert into _guion (paso, resp, leer, ids, rojo57, filas) values (p_nombre, r, l, i, k, f);
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
// `conFilas`: (cuarta vuelta) cada paso lleva además las filas de la Bandeja de ese momento (despues.filas), cuando el guion cambia
// lo que el banco propone para un movimiento que ya esperaba
function guion(nombre, cuerpo, conFilas) {
  // (tercera vuelta) y las filas de los movimientos que LLEGARON durante el guion (pg_temp.llega): no están en la Bandeja del
  // principio, y la pantalla las necesita para pintarlos
  const sql = ['begin;', AYUDA, `do $g$\ndeclare r jsonb; r2 jsonb; t text;\nbegin\n${cuerpo}\nend $g$;`,
    `select coalesce(jsonb_agg(jsonb_build_object('paso', paso, 'resp', resp, 'leer', leer, 'ids', ids, 'rojo57', rojo57${conFilas ? ", 'filas', filas" : ''}) order by n), '[]'::jsonb)::text from _guion;`,
    `select coalesce(pg_temp.pedir($q$select coalesce(jsonb_agg(to_jsonb(b) order by b.fecha, b.movimiento_id), '[]'::jsonb) from v_banco_bandeja b
       where b.movimiento_id in (select s.movimiento from public.f19_semilla s where s.clave not in (${Object.keys(ids).map(k => `'${k}'`).join(', ')}))$q$, 'dueno'), '[]'::jsonb)::text;`,
    'rollback;'].join('\n');
  const out = psql(sql).split('\n').filter(l => l.length);
  const pasos = JSON.parse(out[out.length - 2]), nuevas = sano(JSON.parse(out[out.length - 1]), `guion ${nombre}: las filas que llegaron`);
  if (!pasos.length) throw new Error(`guion ${nombre}: no dejó ningún paso`);
  return pasos.map(p => { if (p.resp && p.resp.ERROR && !/^MX/.test(p.resp.ERROR)) throw new Error(`guion ${nombre}, ${p.paso}: ${p.resp.ERROR}: ${p.resp.message}`);
    // (con `conFilas`, «nuevas» son las filas de ESE paso que no estaban al principio o que ya no son iguales: pantalla.js las pone
    // encima de las del principio)
    const distintas = conFilas ? sano(p.filas, `guion ${nombre}, ${p.paso}: las filas`).filter(f => JSON.stringify(f) !== FILA0.get(f.movimiento_id)) : nuevas;
    return { paso: p.paso, resp: p.resp, despues: { ids: p.ids, leer: resto(p.leer), rojo57: p.rojo57, ...(distintas.length ? { nuevas: distintas } : {}) } }; });
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
const propDe = k => psql(`select id from contador_propuestas where movimiento_id = '${ids[k]}' and estado = 'pendiente'`).trim();
const propIA = propDe('fe1');
const anio = Number(psql('select extract(year from fn_fecha_miami(now()))::int').trim());
const [bandeja, leer, facturas, cuentas, proyectos, validar] = pedir([FILAS, LEER, { sql: 'select fn_bandeja_facturas()' },
  { sql: `select jsonb_agg(jsonb_build_object('codigo', c.codigo, 'nombre', c.nombre, 'tipo', c.tipo, 'regla_obra', c.regla_obra) order by c.codigo) from cuentas c where c.imputable and c.activa` },
  { sql: `select jsonb_agg(jsonb_build_object('id', p.id, 'nombre', p.nombre, 'estado', p.estado) order by p.nombre) from proyectos p` },
  { sql: `select fn_bandeja_validar('${ids.hd3}', 'gasto', ${j({ cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' })})` }]).map((r, i) => sano(r, 'lo del principio ' + i));
LEER0 = leer;
// (las filas del principio, para saber cuáles cambia un guion)
const FILA0 = new Map(bandeja.map(f => [f.movimiento_id, JSON.stringify(f)]));
const rec = k => { const t = leer.tarjetas[ids[k]]; if (!t || !t.rec || !t.rec.accion) throw new Error(`la semilla ya no deja una recomendación para «${k}»: ${JSON.stringify(t)}`); return t.rec; };
const sinRec = k => { const t = leer.tarjetas[ids[k]]; if (!t || (t.rec && t.rec.accion)) throw new Error(`«${k}» no debía traer recomendación: ${JSON.stringify(t)}`); };
// lo que la semilla tiene que dejar (si cambia, las comprobaciones de la pantalla dejarían de valer: falla aquí)
const espera = (k, accion, fuente) => { const r = rec(k); if (r.accion !== accion || (fuente && r.fuente !== fuente)) throw new Error(`«${k}» debía recomendarse como ${accion}${fuente ? ' (' + fuente + ')' : ''} y salió ${r.accion} (${r.fuente})`); };
espera('hd1', 'gasto', 'nombre'); espera('hd3', 'gasto', 'nombre'); espera('nf1', 'personal', 'nombre'); espera('ww1', 'gasto', 'nombre');
espera('od1', 'prestamo', 'app'); espera('in1', 'cobro', 'app'); espera('zl1', 'cobro', 'app'); espera('cu1', 'banco', 'banco'); espera('it1', 'banco', 'banco');
// (tercera vuelta) LA PROPUESTA DE LA IA DE ANTES (c8), dicha como las demás: un gasto de su categoría, «es tuyo», o un gasto de
// obra con la obra firme que ella propone; sin códigos de cuenta ni su motivo crudo, y con la propuesta de la que sale
espera('fe1', 'gasto', 'ia'); espera('ia2', 'personal', 'ia'); espera('ia3', 'gasto', 'ia');
for (const k of ['fe1', 'ia2', 'ia3']) {
  const r = rec(k);
  if (r.propuesta_ia !== propDe(k) || /\b\d{4}\b|distribuciones|una ferretería|donde estuvo la cuadrilla/i.test(`${r.texto} ${r.porque || ''}`.replace(/\$[\d,.]+/g, ''))) throw new Error(`la propuesta de c8 de «${k}» debía salir en llano y con su propuesta: ${JSON.stringify(r)}`);
}
if (!/^Es tuyo, no de la empresa/.test(rec('ia2').texto) || rec('ia3').datos.proyecto_id !== 'oficina-nch-7xq2' || rec('ia3').pide_obra) throw new Error('lo personal y el gasto de obra de c8 no salieron como la semilla los monta: ' + JSON.stringify([rec('ia2'), rec('ia3')]));
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
// (tercera vuelta) un ayuntamiento cobra cosas distintas con el mismo nombre: el permiso y la luz son contrapartes distintas, cada
// uno con su tarjeta y sin grupo. El grupo «mezclado» es ahora el de la ferretería: la IA de antes manda un cargo a herramienta y
// el otro a una obra, así que el grupo no propone nada
if (leer.tarjetas[ids.co1].clave === leer.tarjetas[ids.co2].clave || (leer.grupos || []).some(g => g.movimientos.includes(ids.co1) || g.movimientos.includes(ids.co2))) throw new Error('el permiso y la luz de la ciudad debían ser contrapartes distintas, sin grupo: ' + JSON.stringify([leer.tarjetas[ids.co1].clave, leer.tarjetas[ids.co2].clave]));
if (!gr(leer.tarjetas[ids.fe1].clave).mixto || gr(leer.tarjetas[ids.fe1].clave).rec || leer.tarjetas[ids.ia3].clave !== leer.tarjetas[ids.fe1].clave) throw new Error('el grupo de la ferretería debía salir mezclado y sin recomendación');
if (gr('C:ZZ MADERAS DEL SUR').rec || gr('C:ZZ MADERAS DEL SUR').mixto) throw new Error('el grupo de la maderera debía salir sin decidir');
if (!gr('P:INTUIT').uno_a_uno || gr('P:INTUIT').rec) throw new Error('los depósitos del procesador debían ir juntos pero de uno en uno');
if ((leer.grupos || []).length !== 7 || (leer.control || []).length) throw new Error(`se esperaban 7 grupos y ningún aviso del control: ${JSON.stringify((leer.grupos || []).map(x => x.clave))} · ${JSON.stringify(leer.control)}`);

// una acción suelta: lo que contesta y cómo queda la Bandeja (en su transacción, que se deshace)
const sueltas = {};
const movsDe = c => gr(c).movimientos;
// (tercera vuelta) `de`: los movimientos que la acción contesta. Después de registrar, la pantalla pide solo las tarjetas de SUS
// HERMANOS (los demás pendientes de la misma contraparte): aquí se le pide eso mismo a la base, en la misma transacción repetida, y
// se comprueba que es lo que f19-parte.js saca de la lectura entera de después (con lo que pantalla.js contesta esas lecturas)
let partesComprobadas = 0;
function suelta(clave, firma, orden, pideHecho, de) {
  const [resp, despues, quedan] = pedir([orden, LEER, IDS]);
  sano(resp, clave);
  if (pideHecho === true && resp.hecho !== true && !(Number(resp.hechos) > 0)) throw new Error(`${clave}: debía registrarse y no: ${JSON.stringify(resp).slice(0, 300)}`);
  if (pideHecho === false && (resp.hecho === true || Number(resp.hechos) > 0)) throw new Error(`${clave}: no debía registrarse y sí`);
  sueltas[clave] = { firma, resp, despues: { ids: sano(quedan, clave), leer: resto(despues) } };
  if (de && (resp.hecho === true || Number(resp.hechos) > 0)) {
    const claves = new Set(de.map(id => (LEER0.tarjetas[id] || {}).clave).filter(Boolean));
    const hermanos = quedan.filter(id => despues.tarjetas[id] && claves.has(despues.tarjetas[id].clave));
    const [, entera, parte] = pedir([orden, LEER, { sql: `select fn_bandeja_leer(${j({ ids: hermanos })})` }]);
    const a = JSON.stringify(comparable(sano(parte, clave + ' por partes'))), b = JSON.stringify(comparable(parteDe(sano(entera, clave), hermanos)));
    // (los instantes —«el»— de lo recién registrado cambian de una transacción a otra: no se comparan)
    const sinHora = t => t.replace(/"(el|creado_el|cambiada_el|ultima_vez)":"[^"]*"/g, '"$1":"…"').replace(/"(hecho_id|tanda|asiento_id|dimelo_id)":"[0-9a-f-]{36}"/g, '"$1":"…"').replace(/asiento \d{4}-\d+/g, 'asiento …').replace(/"asiento":"\d{4}-\d+"/g, '"asiento":"…"');
    if (sinHora(a) !== sinHora(b)) {
      let i = 0; const x = sinHora(a), y = sinHora(b); while (i < x.length && x[i] === y[i]) i++;
      throw new Error(`${clave}: lo que la base contesta a {ids: los ${hermanos.length} hermanos} no es lo que f19-parte.js saca de la lectura entera:\n  base: …${x.slice(Math.max(0, i - 120), i + 200)}\n  proy: …${y.slice(Math.max(0, i - 120), i + 200)}`);
    }
    partesComprobadas += 1;
  }
}
const R = { fuente: 'recomendacion', recordar: true };
// (la firma: la función, el movimiento o el grupo, la acción y lo que distingue una llamada de otra; pantalla.js arma la misma)
suelta('asi_wawa', `hacer|${ids.ww1}|gasto||`, hacer(ids.ww1, 'gasto', rec('ww1').datos, R), true, [ids.ww1]);
suelta('asi_hd_dia', `hacer|${ids.hd1}|gasto|casa-perez-k3m9|`, hacer(ids.hd1, 'gasto', rec('hd1').datos, R), true, [ids.hd1]);
suelta('hd_sin_obra', `hacer|${ids.hd3}|gasto||`, hacer(ids.hd3, 'gasto', { cuenta: '5100' }, R), false);
suelta('asi_hd_obra', `hacer|${ids.hd3}|gasto|oficina-nch-7xq2|`, hacer(ids.hd3, 'gasto', { cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' }, R), true, [ids.hd3]);
suelta('asi_netflix', `hacer|${ids.nf1}|personal||`, hacer(ids.nf1, 'personal', rec('nf1').datos, R), true, [ids.nf1]);
suelta('asi_ondeck', `hacer|${ids.od1}|prestamo||`, hacer(ids.od1, 'prestamo', rec('od1').datos, R), true, [ids.od1]);
suelta('asi_intuit', `hacer|${ids.in1}|cobro||`, hacer(ids.in1, 'cobro', rec('in1').datos, R), true, [ids.in1]);
suelta('asi_zelle_llc', `hacer|${ids.zl1}|cobro||`, hacer(ids.zl1, 'cobro', rec('zl1').datos, R), true, [ids.zl1]);
suelta('asi_cuota', `hacer|${ids.cu1}|banco||`, hacer(ids.cu1, 'banco', rec('cu1').datos, { fuente: 'recomendacion' }), true, [ids.cu1]);
suelta('mas_parcial', `hacer|${ids.dp1}|cobro||`, hacer(ids.dp1, 'cobro', { facturas: [{ id: '-1900004', monto: '1000.00' }] }, { fuente: 'mas' }), true, [ids.dp1]);
suelta('mas_aporte_sin', `hacer|${ids.at1}|aporte||`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' }, { fuente: 'mas' }), false);
// (segunda vuelta) el banco cree que ese depósito lo explica una factura: la línea que Edgar escribe («de dónde salió») NO apaga ese
// freno; la puerta lo dice y pide su porqué, y solo con él (y la huella de ese freno) entra
suelta('mas_aporte_con', `hacer|${ids.at1}|aporte||m`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' }, { fuente: 'mas', motivo: 'efectivo mío que metí para cubrir la semana' }), false);
if (!sueltas.mas_aporte_con.resp.freno || sueltas.mas_aporte_con.resp.pide_motivo !== true) throw new Error('el dinero del dueño en un depósito que el banco cree de una factura debía frenar con su huella: ' + JSON.stringify(sueltas.mas_aporte_con.resp));
suelta('mas_aporte_visto', `hacer|${ids.at1}|aporte||mv`, hacer(ids.at1, 'aporte', { tipo: 'prestamo_accionista' },
  { fuente: 'mas', motivo: 'efectivo mío que metí para cubrir la semana. no es de ningún cliente: lo saqué de mi cuenta', visto: sueltas.mas_aporte_con.resp.freno }), true, [ids.at1]);
suelta('mas_anticipo', `hacer|${ids.at1}|anticipo|casa-perez-k3m9|`, hacer(ids.at1, 'anticipo', { proyecto_id: 'casa-perez-k3m9' }, { fuente: 'mas' }), true, [ids.at1]);
// (segunda vuelta) lo que el banco ya reconoce, en llano: el pago de la tarjeta
suelta('asi_tarjeta', `hacer|${ids.tj1}|banco||`, hacer(ids.tj1, 'banco', rec('tj1').datos, { fuente: 'recomendacion' }), true, [ids.tj1]);
// EL FRENO DEL BANCO y su huella: «entre mis cuentas» en algo que el banco no reconoce como traspaso. Sin porqué, la puerta frena y
// lo dice; un porqué SIN la huella de ese freno no lo levanta; con ella, entra
suelta('mas_traspaso_freno', `hacer|${ids.tr1}|traspaso||`, hacer(ids.tr1, 'traspaso', { cuenta: '1030' }, { fuente: 'mas', recordar: true }), false);
if (!sueltas.mas_traspaso_freno.resp.freno || sueltas.mas_traspaso_freno.resp.pide_motivo !== true) throw new Error('el traspaso que el banco no reconoce debía frenar con su huella: ' + JSON.stringify(sueltas.mas_traspaso_freno.resp));
suelta('mas_traspaso_sin_ver', `hacer|${ids.tr1}|traspaso||m`, hacer(ids.tr1, 'traspaso', { cuenta: '1030' }, { fuente: 'mas', recordar: true, motivo: 'lo pasé a la reserva de impuestos' }), false);
suelta('mas_traspaso_visto', `hacer|${ids.tr1}|traspaso||mv`, hacer(ids.tr1, 'traspaso', { cuenta: '1030' }, { fuente: 'mas', recordar: true, motivo: 'lo pasé a la reserva de impuestos', visto: sueltas.mas_traspaso_freno.resp.freno }), true, [ids.tr1]);
// EL PAGO A LA CUADRILLA que c10 apunta y no registra (avisa de algo): «dicho»; la tarjeta pasa a ser la de la mano de obra
suelta('mas_cuadrilla', `hacer|${ids.zp1}|cuadrilla||`, hacer(ids.zp1, 'cuadrilla', { usuario_id: '00000000-0000-4000-a000-000000000002' }, { fuente: 'mas', recordar: true }), false);
if (sueltas.mas_cuadrilla.resp.dicho !== true) throw new Error('el pago a la cuadrilla debía quedar «dicho» (apuntado, sin registrar): ' + JSON.stringify(sueltas.mas_cuadrilla.resp));
// el pago a un subcontratista, con su nombre
suelta('mas_contratista', `hacer|${ids.zp1}|contratista|oficina-nch-7xq2|`, hacer(ids.zp1, 'contratista', { proyecto_id: 'oficina-nch-7xq2', proveedor_id: leer.proveedores[0].proveedor_id }, { fuente: 'mas', recordar: true }), true, [ids.zp1]);
// el préstamo sin dar de alta: registrado, el control de la Bandeja lo dice (en llano) en lo que lee la pantalla
if (!((sueltas.asi_ondeck.despues.leer.control || []).some(k => Number(k.orden) === 70))) throw new Error('tras registrar el préstamo sin alta, la lectura debía traer el aviso 70 del control: ' + JSON.stringify(sueltas.asi_ondeck.despues.leer.control));
suelta('lote_cuotas', 'grupo|M:cuota_prestamo||', grupo('M:cuota_prestamo', null, {}, { movimientos: movsDe('M:cuota_prestamo') }), true, movsDe('M:cuota_prestamo'));
suelta('lote_intereses', 'grupo|M:interes_tarjeta||', grupo('M:interes_tarjeta', null, {}, { movimientos: movsDe('M:interes_tarjeta') }), true, movsDe('M:interes_tarjeta'));
suelta('grupo_hd_dia', 'grupo|C:HOME DEPOT|gasto|', grupo('C:HOME DEPOT', 'gasto', { cuenta: '5100' }, { movimientos: movsDe('C:HOME DEPOT'), recordar: true, solo: false }), true, movsDe('C:HOME DEPOT'));
suelta('grupo_hd_obra', 'grupo|C:HOME DEPOT|gasto|oficina-nch-7xq2', grupo('C:HOME DEPOT', 'gasto', { cuenta: '5100', proyecto_id: 'oficina-nch-7xq2' }, { movimientos: movsDe('C:HOME DEPOT'), recordar: true, solo: false }), true, movsDe('C:HOME DEPOT'));
// (tercera vuelta) el grupo de la ferretería decidido como «Herramienta menor y uniformes»: es LO MISMO que la IA de antes proponía
// para uno de sus dos cargos (el otro lo mandaba a una obra). Las dos propuestas quedan abiertas (propuestas_ia) y la base dice
// cuál proponía lo mismo (propuestas_ia_iguales): la pantalla la cierra sin decir que Edgar contestó otra cosa
suelta('grupo_ferre', 'grupo|C:ZZ FERRETERIA CENTRAL|gasto|', grupo('C:ZZ FERRETERIA CENTRAL', 'gasto', { cuenta: '6400' }, { movimientos: movsDe('C:ZZ FERRETERIA CENTRAL'), recordar: true, solo: false }), true, movsDe('C:ZZ FERRETERIA CENTRAL'));
{
  const r = sueltas.grupo_ferre.resp, todas = r.propuestas_ia || [], iguales = r.propuestas_ia_iguales || [];
  if (Number(r.hechos) !== 2 || todas.length !== 2 || iguales.length !== 1 || iguales[0] !== propDe('fe1') || !todas.includes(propDe('ia3')))
    throw new Error('el grupo de la ferretería como herramienta debía registrar los dos y decir que solo la propuesta de fe1 proponía lo mismo: ' + JSON.stringify(r).slice(0, 500));
}
// (segunda vuelta) los depósitos NO se deciden por grupo: la base lo rechaza con su regla (MX008), dicho en llano
const grupoDep = pedir([grupo('P:INTUIT', 'anticipo', { proyecto_id: 'casa-perez-k3m9' }, { movimientos: movsDe('P:INTUIT') })])[0];
if (!grupoDep || grupoDep.ERROR !== 'MX008') throw new Error('decidir por grupo los depósitos del procesador debía rechazarse con MX008: ' + JSON.stringify(grupoDep));
if (partesComprobadas < 12) throw new Error(`solo se comprobó la lectura por partes de ${partesComprobadas} acciones`);
console.log(`  ${Object.keys(sueltas).length} acciones sueltas (la lectura por partes de los hermanos, comprobada contra la base en ${partesComprobadas})`);

// LOS GUIONES (segunda vuelta): varios pasos en una transacción
const guiones = {};
// EL RECIBO QUE LLEGA DESPUÉS. Tres compras con la tarjeta de obra se registran desde la Bandeja (a ZZ Oficina Norte) y DESPUÉS la
// cuadrilla sube sus recibos (a ZZ Casa Roble). (Tercera vuelta) NINGUNO SE CAMBIA SOLO —el banco no deja volver atrás un cambio
// así—: los tres esperan arriba, cada uno con «es su recibo» y «es otra compra». De las dos compras iguales no se sabe de cuál es
// el recibo: a una se le dice «es otra compra» (frena, y con su porqué queda) y a la otra «es su recibo»; y la suelta, «es su recibo»
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
         '{"fuente":"mas"}')$q$);
  perform pg_temp.paso('recibo_suelto', $q$select fn_bandeja_hacer((fn_bandeja_leer()->'recibos'->0->>'movimiento_id')::uuid, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'recibos'->0->'opciones') o where o->>'es' = 'recibo'),
         '{"fuente":"mas"}')$q$);`);
{
  const g = Object.fromEntries(guiones.recibos.map(p => [p.paso, p])), rs = p => (g[p].despues.leer.recibos || LEER0.recibos || []);
  if (!g.inicio.despues.rojo57 || rs('inicio').length) throw new Error('guion recibos: al principio el control debía decir que hay un gasto dos veces y la Bandeja todavía no saberlo');
  if ('cambiados' in (g.solo.resp.recibos || {}) || g.solo.resp.recibos.esperan !== 3 || rs('solo').length !== 3 || !g.solo.despues.rojo57 || (g.solo.resp.registrados || []).length) throw new Error('guion recibos: la rutina no debía cambiar ninguno, y dejar los tres esperando: ' + JSON.stringify(g.solo.resp));
  // (los dos primeros son las compras iguales —el mismo día, el mismo monto—; el tercero, la suelta)
  if (rs('solo')[0].monto !== rs('solo')[1].monto || rs('solo')[2].monto === rs('solo')[0].monto) throw new Error('guion recibos: se esperaban primero las dos compras iguales y después la suelta: ' + JSON.stringify(rs('solo').map(x => x.monto)));
  if (g.otra_freno.resp.hecho !== false || !g.otra_freno.resp.freno || g.otra_visto.resp.hecho !== true || rs('otra_visto').length !== 2) throw new Error('guion recibos: «es otra compra» debía frenar y, con su porqué leído, quedar: ' + JSON.stringify([g.otra_freno.resp, g.otra_visto.resp]).slice(0, 500));
  if (g.recibo.resp.hecho !== true || rs('recibo').length !== 1 || !g.recibo.despues.rojo57) throw new Error('guion recibos: «es su recibo» debía cambiarlo y dejar el de la compra suelta esperando: ' + JSON.stringify(g.recibo.resp).slice(0, 300));
  if (g.recibo_suelto.resp.hecho !== true || rs('recibo_suelto').length || g.recibo_suelto.despues.rojo57) throw new Error('guion recibos: el último «es su recibo» debía dejar el banco en verde: ' + JSON.stringify(g.recibo_suelto.resp).slice(0, 300));
}
// UNA DECISIÓN POR GRUPO QUE SE DESHACE ENTERA (su tanda)
guiones.tanda = guion('tanda', `
  r := pg_temp.paso('grupo', format($q$select fn_bandeja_grupo('C:HOME DEPOT', 'gasto', '{"cuenta":"5100","proyecto_id":"oficina-nch-7xq2"}', %L)$q$,
         jsonb_build_object('movimientos', (select jsonb_agg(pg_temp.mov(k)) from unnest(array['hd1','hd2','hd3','hd4']) k), 'recordar', true, 'solo', false)));
  perform pg_temp.paso('deshacer_tanda', format($q$select fn_bandeja_deshacer_tanda(%L, 'me equivoqué de obra')$q$, r->>'tanda'));`);
{
  const [a, b] = guiones.tanda;
  if (Number(a.resp.hechos) !== 4 || !a.resp.tanda || (a.despues.leer.tandas || []).length !== 1 || Number(a.despues.leer.tandas[0].n) !== 4) throw new Error('guion tanda: el grupo debía registrar los cuatro con su tanda: ' + JSON.stringify(a.resp).slice(0, 300));
  if (Number(b.resp.deshechos) !== 4 || (b.despues.leer.tandas || LEER0.tandas || []).length || b.resp.solo_apagado) throw new Error('guion tanda: deshacer la tanda debía devolver los cuatro (y no había ninguna regla «que entre solo» que apagar): ' + JSON.stringify(b.resp));
}
// (tercera vuelta) DESHACER LA RESPUESTA QUE PUSO «QUE ENTRE SOLO»: el grupo de Netflix se contesta «es mío» con «que lo siguiente
// entre solo»; al deshacer esa decisión entera, la regla SE APAGA (la base lo hace y dice de quién), y el cargo que llega después
// espera en la Bandeja. Y si Edgar desmarca la casilla (deja_solo: false), la regla sigue y el cargo siguiente entra solo
const NETFLIX_SOLO = `r := pg_temp.paso('grupo_solo', format($q$select fn_bandeja_grupo('C:NETFLIX', 'personal', '{}', %L)$q$,
         jsonb_build_object('movimientos', (select jsonb_agg(pg_temp.mov(k)) from unnest(array['nf1','nf2']) k), 'recordar', true, 'solo', true)));`;
guiones.tanda_solo = guion('tanda_solo', `
  ${NETFLIX_SOLO}
  perform pg_temp.paso('deshacer_tanda', format($q$select fn_bandeja_deshacer_tanda(%L, 'no eran míos: son de la oficina')$q$, r->>'tanda'));
  perform pg_temp.llega('nf5', 1, -15.49, 'NETFLIX.COM');
  perform pg_temp.paso('solo', $q$select fn_bandeja_solo('{"corrio":"pantalla"}')$q$);`);
guiones.tanda_deja = guion('tanda_deja', `
  ${NETFLIX_SOLO}
  perform pg_temp.paso('deshacer_tanda', format($q$select fn_bandeja_deshacer_tanda(%L, 'me equivoqué de mes', '{"deja_solo": false}')$q$, r->>'tanda'));`);
{
  const [a, b, c] = guiones.tanda_solo, [, d] = guiones.tanda_deja;
  const regla = l => ((l.memoria || LEER0.memoria || []).find(x => x.clave === 'C:NETFLIX') || {});
  if (Number(a.resp.hechos) !== 2 || !(a.resp.recordado || {}).solo || regla(a.despues.leer).solo !== true || !(a.despues.leer.tandas || [])[0] || a.despues.leer.tandas[0].clave !== 'C:NETFLIX') throw new Error('guion tanda_solo: el grupo debía entrar con «que lo siguiente entre solo» y su tanda traer la clave: ' + JSON.stringify(a.resp).slice(0, 300));
  if (Number(b.resp.deshechos) !== 2 || b.resp.solo_apagado !== 'NETFLIX' || regla(b.despues.leer).solo !== false) throw new Error('guion tanda_solo: deshacer la tanda debía apagar «entra solo» de Netflix: ' + JSON.stringify(b.resp));
  if ((c.resp.registrados || []).length || c.despues.ids.length !== b.despues.ids.length + 1) throw new Error('guion tanda_solo: el cargo que llegó después debía esperar en la Bandeja: ' + JSON.stringify(c.resp));
  if (Number(d.resp.deshechos) !== 2 || d.resp.solo_apagado || regla(d.despues.leer).solo !== true) throw new Error('guion tanda_deja: con deja_solo en falso la regla debía seguir encendida: ' + JSON.stringify(d.resp));
}
// (tercera vuelta) LA TARIFA DE UN PROCESADOR, a la vista y con su «Olvidar»: el cobro con comisión que Edgar confirma deja
// confirmada la tarifa que lo explica; olvidarla le quita esa confirmación
guiones.tarifa = guion('tarifa', `
  perform pg_temp.paso('cobro', format($q$select fn_bandeja_hacer(%L, 'cobro', %L, '{"fuente":"recomendacion","recordar":true}')$q$, pg_temp.mov('in1'), ${dolar(JSON.stringify(rec('in1').datos))}));
  perform pg_temp.paso('olvidar', $q$select fn_bandeja_tarifa_olvidar((fn_bandeja_leer()->'tarifas'->0) - 'veces' - 'origen', true)$q$);`);
{
  const [a, b] = guiones.tarifa, ts = a.despues.leer.tarifas || [];
  if (a.resp.hecho !== true || ts.length !== 1 || ts[0].proc !== 'INTUIT' || !(Number(ts[0].veces) > 0)) throw new Error('guion tarifa: el cobro con comisión debía dejar confirmada una tarifa de Intuit: ' + JSON.stringify(ts));
  if (!b.resp || (b.despues.leer.tarifas || []).length) throw new Error('guion tarifa: olvidarla debía quitarla de lo que se lee: ' + JSON.stringify([b.resp, b.despues.leer.tarifas]));
}
// (tercera vuelta) UN GRUPO QUE NO ENTRA ENTERO: los cuatro de Home Depot con «la obra del día de cada uno»: entran los dos del día
// de una sola obra y se quedan dos sin obra. El grupo sigue (con dos), su recomendación dice que a esos les falta la obra (ya no
// ofrece «la del día», que no puede avanzar) y, eligiendo una para los dos, entran
guiones.hd_resto = guion('hd_resto', `
  perform pg_temp.paso('grupo_dia', format($q$select fn_bandeja_grupo('C:HOME DEPOT', 'gasto', '{"cuenta":"5100"}', %L)$q$,
         jsonb_build_object('movimientos', (select jsonb_agg(pg_temp.mov(k)) from unnest(array['hd1','hd2','hd3','hd4']) k), 'recordar', true, 'solo', false)));
  perform pg_temp.paso('grupo_obra', format($q$select fn_bandeja_grupo('C:HOME DEPOT', 'gasto', '{"cuenta":"5100","proyecto_id":"oficina-nch-7xq2"}', %L)$q$,
         jsonb_build_object('movimientos', (select jsonb_agg(pg_temp.mov(k)) from unnest(array['hd3','hd4']) k), 'recordar', true, 'solo', false)));`);
{
  const [a, b] = guiones.hd_resto, g2 = (a.despues.leer.grupos || []).find(x => x.clave === 'C:HOME DEPOT');
  if (Number(a.resp.hechos) !== 2 || (a.resp.quedan || []).length !== 2 || !a.resp.quedan.every(x => x.pide_obra) || (a.resp.registrados || []).length !== 2) throw new Error('guion hd_resto: debían entrar dos y quedarse dos pidiendo la obra: ' + JSON.stringify(a.resp).slice(0, 400));
  if (!g2 || g2.movimientos.length !== 2 || !g2.rec || g2.rec.falta_obra !== true || !/les falta la obra/.test(g2.rec.texto)) throw new Error('guion hd_resto: el grupo que queda debía decir que a los dos les falta la obra: ' + JSON.stringify(g2));
  if (Number(b.resp.hechos) !== 2 || (b.resp.quedan || []).length) throw new Error('guion hd_resto: con la obra para los dos debían entrar: ' + JSON.stringify(b.resp).slice(0, 300));
}
// LO YA CONTESTADO, TOCADO OTRA VEZ (otra pestaña, o la contestación que se perdió): «fuera»
guiones.fuera = guion('fuera', `
  perform pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"6300"}', '{"fuente":"recomendacion","recordar":true}')$q$, pg_temp.mov('ww1')));
  perform pg_temp.paso('otra_vez', format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"6300"}', '{"fuente":"recomendacion","recordar":true}')$q$, pg_temp.mov('ww1')));`);
if (guiones.fuera[0].resp.hecho !== true || guiones.fuera[1].resp.fuera !== true) throw new Error('guion fuera: la segunda vez debía decir «fuera»: ' + JSON.stringify(guiones.fuera[1].resp));
// ---------- (cuarta vuelta) LO QUE ENCONTRÓ LA TERCERA REVISIÓN ----------
const DUENO_ES = `perform set_config('request.jwt.claims', json_build_object('sub', '${DUENO}', 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform set_config('request.jwt.claim.sub', '${DUENO}', true);`;
const NADIE_ES = `perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);`;
// EL RECIBO QUE LLEGA DESPUÉS, EN EL OTRO ORDEN: de las dos compras iguales con UN recibo, «es su recibo» en la PRIMERA (el botón
// principal de la tarjeta de arriba). Antes la segunda seguía arriba diciendo que su gasto estaba dos veces (ya no era verdad), con
// dos botones que fallaban. Ahora la base lo mira en esa misma llamada: solo queda esperando la compra suelta
guiones.recibos2 = guion('recibos2', `
  perform pg_temp.pedir(format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"5100","proyecto_id":"oficina-nch-7xq2"}', '{"fuente":"mas"}')$q$, pg_temp.mov(k))) from unnest(array['rc1','rc2','rc3']) k;
  insert into recibos (id, proyecto_id, ruta, total, proveedor, notas, estado, autor_id, creado, fecha, categoria, num_recibo, metodo_pago, ultimos4)
  overriding system value values
    (-1900021, 'casa-perez-k3m9', 'recibos/f19/1900021.jpg', 64.37, 'ZZ MADERAS DEL SUR', 'f19-capturar', 'leido', '${DUENO}', now(), fn_fecha_miami(now()) - 5, 'material', 'ZZ19-R1', 'credito', '9919'),
    (-1900023, 'casa-perez-k3m9', 'recibos/f19/1900023.jpg', 77.31, 'ZZ ELECTRICA TOTAL', 'f19-capturar', 'leido', '${DUENO}', now(), fn_fecha_miami(now()) - 4, 'material', 'ZZ19-R3', 'credito', '9919');
  perform fn_puentes_correr();
  perform pg_temp.paso('inicio', 'select null::jsonb');
  perform pg_temp.paso('solo', $q$select fn_bandeja_solo('{"corrio":"pantalla"}')$q$);
  perform pg_temp.paso('recibo', $q$select fn_bandeja_hacer((fn_bandeja_leer()->'recibos'->0->>'movimiento_id')::uuid, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'recibos'->0->'opciones') o where o->>'es' = 'recibo'),
         '{"fuente":"mas"}')$q$);
  perform pg_temp.paso('recibo_suelto', $q$select fn_bandeja_hacer((fn_bandeja_leer()->'recibos'->0->>'movimiento_id')::uuid, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'recibos'->0->'opciones') o where o->>'es' = 'recibo'),
         '{"fuente":"mas"}')$q$);`);
{
  const g = Object.fromEntries(guiones.recibos2.map(p => [p.paso, p])), rs = p => (g[p].despues.leer.recibos || LEER0.recibos || []);
  if (rs('solo').length !== 3 || rs('solo')[0].monto !== rs('solo')[1].monto) throw new Error('guion recibos2: se esperaban los tres esperando, primero las dos compras iguales: ' + JSON.stringify(rs('solo').map(x => x.monto)));
  if (g.recibo.resp.hecho !== true || rs('recibo').length !== 1 || rs('recibo')[0].monto === rs('solo')[0].monto || !g.recibo.despues.rojo57)
    throw new Error('guion recibos2: tras «es su recibo» en la primera de las dos iguales debía quedar esperando SOLO la compra suelta (la otra igual ya no tiene recibo libre): ' + JSON.stringify(rs('recibo').map(x => [x.descripcion, x.monto])));
  if (g.recibo_suelto.resp.hecho !== true || rs('recibo_suelto').length || g.recibo_suelto.despues.rojo57) throw new Error('guion recibos2: el último «es su recibo» debía dejar el banco en verde: ' + JSON.stringify(g.recibo_suelto.resp).slice(0, 300));
}
// EL BANCO LO RECONOCE DE VARIAS FORMAS IGUAL DE VÁLIDAS: con una segunda tarjeta del mismo banco dada de alta, el pago de la tarjeta
// desde el banco ya no se da por hecho con la primera opción (antes: «Es el pago de tu tarjeta Amex Business Blue», la que el banco
// ordena primero). La tarjeta PREGUNTA cuál; la elegida se registra por su huella
guiones.elige = guion('elige', `
  perform fn_tarjeta_alta('2009', '2100-2009', 'f19-capturar: la segunda tarjeta del mismo banco');
  ${DUENO_ES}
  perform fn_banco_casar(pg_temp.mov('tj1'));
  ${NADIE_ES}
  perform pg_temp.paso('inicio', 'select null::jsonb');
  perform pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%L, 'banco',
         (select jsonb_build_object('opcion', o->'opcion', 'huella', o->>'huella') from jsonb_array_elements(fn_bandeja_leer()->'tarjetas'->%L->'rec'->'elige') o where o->>'boton' ~ 'Gold'),
         '{"fuente":"recomendacion"}')$q$, pg_temp.mov('tj1'), pg_temp.mov('tj1')::text));`, true);
{
  const [a, b] = guiones.elige, t = a.despues.leer.tarjetas[ids.tj1], f = (a.despues.nuevas || []).find(x => x.movimiento_id === ids.tj1);
  if (!t || !t.rec || t.rec.accion || !Array.isArray(t.rec.elige) || t.rec.elige.length < 2 || t.rec.pill !== 'Pago de la tarjeta' || !/¿De cuál es\?$/.test(t.rec.aviso || '')
      || !t.rec.elige.every(o => o.huella && o.boton && o.texto) || !t.rec.elige.some(o => /Gold/.test(o.boton)) || !t.rec.elige.some(o => /Blue/.test(o.boton)))
    throw new Error('guion elige: con dos tarjetas del mismo banco, el pago de la tarjeta debía PREGUNTAR cuál (elige), no recomendar la primera: ' + JSON.stringify(t).slice(0, 600));
  if (!f || (f.opciones || []).length < 2 || (t.ops || []).length !== f.opciones.length) throw new Error('guion elige: la fila del pago de la tarjeta debía traer las opciones del banco y la tarjeta sus huellas: ' + JSON.stringify([f && f.opciones, t.ops]).slice(0, 400));
  if (b.resp.hecho !== true || !/Amex Business Gold/.test(b.resp.texto || '') || b.despues.ids.includes(ids.tj1)) throw new Error('guion elige: la opción elegida (la Gold) debía registrarse: ' + JSON.stringify(b.resp).slice(0, 300));
}
// UN BOTÓN DE «LO QUE DICE EL BANCO» POR LA BANDEJA: llega el Zelle que paga ENTERA una factura sin marcar en Proyectos. La opción
// del banco («Factura #ZZ-104…») se valida (lo que se va a registrar, en llano) y se registra por fn_bandeja_hacer: la factura queda
// COBRADA EN PROYECTOS y el registro en «Lo que contestaste estos días» (por la puerta de antes, de un toque, nada de eso pasaba)
guiones.boton_banco = guion('boton_banco', `
  perform pg_temp.llega('zf1', 2, 1450.75, 'ZELLE PAYMENT FROM ZZ CLIENTE TALLER 778899');
  perform pg_temp.paso('inicio', 'select null::jsonb');
  perform pg_temp.paso('validar', format($q$select fn_bandeja_validar(%L, 'banco', jsonb_build_object('opcion', 0, 'huella', fn_bandeja_leer()->'tarjetas'->%L->'ops'->>0))$q$, pg_temp.mov('zf1'), pg_temp.mov('zf1')::text));
  perform pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%L, 'banco', jsonb_build_object('opcion', 0, 'huella', fn_bandeja_leer()->'tarjetas'->%L->'ops'->>0), '{"fuente":"mas"}')$q$, pg_temp.mov('zf1'), pg_temp.mov('zf1')::text));
  perform pg_temp.paso('proyectos', $q$select jsonb_build_object('pagada', f.pagada, 'cobrado', f.cobrado) from facturas f where f.id = -1900004$q$, 'editor');`, true);
{
  const [a, v, h, pr] = guiones.boton_banco, mov = a.despues.ids.find(id => !Object.values(ids).includes(id)), fila = (a.despues.nuevas || []).find(x => x.movimiento_id === mov);
  const o0 = fila && (fila.opciones || [])[0];
  if (!fila || !o0 || o0.llamar !== 'fn_banco_cobrar' || !/ZZ-104/.test(o0.texto || '')) throw new Error('guion boton_banco: el Zelle que paga la ZZ-104 debía traer esa factura como primera opción del banco: ' + JSON.stringify(fila && fila.opciones).slice(0, 400));
  if (v.resp.ok !== true || !/ZZ-104/.test(v.resp.texto || '') || /\b\d{4}\b/.test(String(v.resp.texto).replace(/\$[\d,.]+/g, '').replace(/#[A-Z0-9-]+/g, ''))) throw new Error('guion boton_banco: la opción debía validarse en llano: ' + JSON.stringify(v.resp).slice(0, 300));
  if (h.resp.hecho !== true || (h.resp.facturas_cobradas || []).length !== 1 || !(h.despues.leer.recientes || []).some(r => r.hecho_id === h.resp.hecho_id) || pr.resp.pagada !== true || Number(pr.resp.cobrado) !== 1450.75)
    throw new Error('guion boton_banco: por la Bandeja, la factura debía quedar cobrada en Proyectos y el registro en lo contestado: ' + JSON.stringify([h.resp, pr.resp]).slice(0, 500));
}
// DESHACER PARA CORREGIR: lo que Edgar deshace no se le recomienda otra vez en la tarjeta que vuelve (se pregunta); y si lo dice
// («y olvida lo que te dije de X»), lo recordado de ese comercio se da de baja en la misma llamada
const WAWA_ASI = `r := pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"6300"}', '{"fuente":"recomendacion","recordar":true}')$q$, pg_temp.mov('ww1')));`;
guiones.deshecha = guion('deshecha', `
  ${WAWA_ASI}
  perform pg_temp.paso('deshacer', format($q$select fn_bandeja_deshacer(%L, 'me equivoqué de categoría')$q$, r->>'hecho_id'));`);
guiones.olvida = guion('olvida', `
  ${WAWA_ASI}
  perform pg_temp.paso('deshacer', format($q$select fn_bandeja_deshacer(%L, 'no es gasolina: es comida', '{"olvida": true}')$q$, r->>'hecho_id'));`);
{
  const [a, b] = guiones.deshecha, [, c] = guiones.olvida, t = b.despues.leer.tarjetas[ids.ww1], t2 = c.despues.leer.tarjetas[ids.ww1];
  const mem = l => (l.memoria || LEER0.memoria || []).find(x => x.clave === 'C:WAWA');
  if (a.resp.hecho !== true || !(a.resp.recordado || {}).nombre || !mem(a.despues.leer)) throw new Error('guion deshecha: el «Así es» debía dejar recordado el comercio: ' + JSON.stringify(a.resp).slice(0, 300));
  if (b.resp.deshecho !== true || b.resp.olvidado || !mem(b.despues.leer) || !t || !t.rec || t.rec.deshecha !== true || t.rec.accion || !/no te lo propongo otra vez/.test(t.rec.aviso || ''))
    throw new Error('guion deshecha: lo deshecho no debía recomendarse otra vez en la tarjeta que vuelve (y lo recordado seguir): ' + JSON.stringify([b.resp, t]).slice(0, 600));
  if (c.resp.deshecho !== true || c.resp.olvidado !== 'WAWA' || mem(c.despues.leer)) throw new Error('guion olvida: con «olvida» lo recordado de ese comercio debía darse de baja: ' + JSON.stringify(c.resp).slice(0, 300));
  if (!t2 || (t2.rec && t2.rec.fuente === 'memoria')) throw new Error('guion olvida: la tarjeta que vuelve no debía recomendar nada de lo recordado: ' + JSON.stringify(t2).slice(0, 300));
}
// LO QUE EL BANCO DICE DE UN PRESTAMISTA: (a) un depósito suyo con facturas mayores abiertas: el banco propone «parte de la factura…»,
// pero la app SABE que es de un prestamista (`sabe`): «Más opciones» no ofrece cobrarlo; (b) un CARGO hacia él es la cuota de un
// préstamo: la tarjeta lo avisa, y registrarlo como un gasto frena (el freno es de esta capa: «propio») y no se recuerda
guiones.prestamista = guion('prestamista', `
  perform pg_temp.llega('od2', 2, 4000.00, 'ORIG CO NAME:ZZLEND CAPITAL ORIG ID:1234567890 DESC DATE:ZZ21');
  perform pg_temp.llega('oc1', 1, -412.33, 'ORIG CO NAME:ZZLEND CAPITAL ORIG ID:1234567890 DESC DATE:ZZ22 DAILY PMT');
  perform pg_temp.paso('inicio', 'select null::jsonb');
  perform pg_temp.paso('gasto_freno', format($q$select fn_bandeja_hacer(%L, 'gasto', '{"cuenta":"7100"}', '{"fuente":"mas"}')$q$, pg_temp.mov('oc1')));`, true);
{
  const [a, b] = guiones.prestamista, nuevas = a.despues.nuevas || [], dep = nuevas.find(x => Number(x.monto) > 0), car = nuevas.find(x => Number(x.monto) < 0);
  const td = dep && a.despues.leer.tarjetas[dep.movimiento_id], tc = car && a.despues.leer.tarjetas[car.movimiento_id];
  if (!dep || !td || td.sabe !== 'prestamista' || !(dep.opciones || []).some(o => o.llamar === 'fn_banco_cobrar') || !td.rec || td.rec.accion !== 'prestamo')
    throw new Error('guion prestamista: el depósito del prestamista debía traer opciones de cobro del banco, saberse de un prestamista y recomendarse como préstamo: ' + JSON.stringify([dep && dep.opciones, td]).slice(0, 600));
  if (!car || !tc || tc.sabe !== 'prestamista' || !tc.rec || tc.rec.accion || !/cuota de un préstamo/i.test(tc.rec.aviso || '') || tc.rec.pill !== 'Cuota de un préstamo') throw new Error('guion prestamista: el cargo hacia el prestamista debía avisarse (es su cuota), sin recomendar un gasto: ' + JSON.stringify(tc).slice(0, 500));
  if (b.resp.hecho !== false || b.resp.propio !== true || !b.resp.freno || b.resp.pide_motivo !== true || !/cuota de un préstamo/.test(b.resp.por_que || '')) throw new Error('guion prestamista: registrarlo como un gasto debía frenar (propio): ' + JSON.stringify(b.resp).slice(0, 400));
}
// (quinta vuelta) EL BOTÓN QUE SE TOCA ES LO QUE SE REGISTRA. El dinero que sale a una cuenta que la app no conoce (cd1): el banco
// guarda cinco opciones y la PRIMERA nombra la cuenta de paso de Stripe, que la pantalla esconde: sus botones quedaban corridos un
// puesto respecto de la base (tocar «Para Edgar…» validaba y registraba «A Reserva de impuestos»). Se captura lo que la base contesta
// a la opción «Para Edgar…» POR SU NÚMERO EN LA BASE: validarla (la distribución al dueño), registrarla (la puerta pide su porqué) y
// registrarla con el porqué leído. Y, aparte (boton_otra), lo que contesta a la opción de al lado («A Reserva…»): con eso pantalla.js
// prueba el segundo candado (si la base valida OTRA opción que la del botón tocado, no se enseña ninguna caja)
const N_OPCION = (clave, donde) => `select (z.n - 1)::text into t from movimientos_banco mb, jsonb_array_elements(mb.propuesta->'opciones') with ordinality z(o, n)
   where mb.id = pg_temp.mov('${clave}') and ${donde} order by z.n limit 1;
  if t is null then raise exception 'f19-capturar: el movimiento ${clave} no trae la opción que el guion busca'; end if;`;
const OPCION_DE = clave => `jsonb_build_object('opcion', %2$s, 'huella', fn_bandeja_leer()->'tarjetas'->%3$L->'ops'->>%2$s)`;
guiones.boton_corrido = guion('boton_corrido', `
  ${N_OPCION('cd1', "z.o->>'texto' ~ '^Para Edgar'")}
  perform pg_temp.paso('inicio', format('select jsonb_build_object(''opcion'', %s)', t));
  perform pg_temp.paso('validar', format($q$select fn_bandeja_validar(%1$L, 'banco', ${OPCION_DE('cd1')})$q$, pg_temp.mov('cd1'), t, pg_temp.mov('cd1')::text));
  r := pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%1$L, 'banco', ${OPCION_DE('cd1')}, '{"fuente":"mas"}')$q$, pg_temp.mov('cd1'), t, pg_temp.mov('cd1')::text));
  perform pg_temp.paso('hacer_motivo', format($q$select fn_bandeja_hacer(%1$L, 'banco', ${OPCION_DE('cd1')},
         jsonb_build_object('fuente', 'mas', 'motivo', 'es mi cuenta personal de siempre', 'visto', %4$L))$q$, pg_temp.mov('cd1'), t, pg_temp.mov('cd1')::text, r->>'freno'));`);
guiones.boton_otra = guion('boton_otra', `
  ${N_OPCION('cd1', "z.o->'args'->>'p_cuenta' = '1030'")}
  perform pg_temp.paso('inicio', format('select jsonb_build_object(''opcion'', %s)', t));
  perform pg_temp.paso('validar', format($q$select fn_bandeja_validar(%1$L, 'banco', ${OPCION_DE('cd1')})$q$, pg_temp.mov('cd1'), t, pg_temp.mov('cd1')::text));`);
{
  const [a, v, h, hm] = guiones.boton_corrido, [oa, ov] = guiones.boton_otra, fila = FILA0.has(ids.cd1) ? JSON.parse(FILA0.get(ids.cd1)) : null, N = a.resp.opcion, M = oa.resp.opcion;
  if (!fila || !Array.isArray(fila.opciones) || fila.opciones.length < 4 || (fila.opciones[0].args || {}).p_cuenta !== '1020' || !/^Para Edgar/.test(fila.opciones[N].texto) || N < 2)
    throw new Error('guion boton_corrido: el dinero a una cuenta que la app no conoce debía traer primero la opción de la cuenta de Stripe (la que la pantalla esconde) y después «Para Edgar…»: ' + JSON.stringify(fila && fila.opciones.map(o => o.texto)).slice(0, 500));
  if (v.resp.ok !== true || !/^Es tuyo, no de la empresa: \$300\.00/.test(v.resp.texto || '') || !v.resp.opcion_banco || v.resp.opcion_banco.llamar !== fila.opciones[N].llamar
      || JSON.stringify(v.resp.opcion_banco.args) !== JSON.stringify(fila.opciones[N].args))
    throw new Error('guion boton_corrido: la opción «Para Edgar…» debía validarse como el retiro del dueño y devolver la opción que validó: ' + JSON.stringify(v.resp).slice(0, 500));
  if (h.resp.hecho !== false || h.resp.pide_motivo !== true || !h.resp.freno || hm.resp.hecho !== true || !/^Es tuyo, no de la empresa/.test(hm.resp.texto || '') || hm.despues.ids.includes(ids.cd1))
    throw new Error('guion boton_corrido: registrarla debía pedir su porqué y, con el porqué leído, entrar: ' + JSON.stringify([h.resp, hm.resp]).slice(0, 500));
  if (M === N || ov.resp.ok !== true || !/Reserva de impuestos/.test(ov.resp.texto || '') || (ov.resp.opcion_banco.args || {}).p_cuenta !== '1030')
    throw new Error('guion boton_otra: la opción de al lado debía ser el traspaso a la reserva: ' + JSON.stringify(ov.resp).slice(0, 400));
}
// (quinta vuelta) «ES OTRO MOVIMIENTO» POR LA BANDEJA: dos peajes iguales el mismo día; el segundo sale como posible duplicado. El botón
// del banco «Es otro movimiento» no registra nada: deja dicho que los dos cuentan. La Bandeja lo dice (anotado, cambio) y la tarjeta
// se lee otra vez (antes: «No se registró: sigue en la Bandeja.», con la respuesta guardada y la tarjeta preguntando lo mismo)
guiones.duplicado = guion('duplicado', `
  perform pg_temp.llega('pj1', 2, -6.50, 'SUNPASS ZZ TOLL 0042 OCALA FL');
  perform pg_temp.llega('pj2', 2, -6.50, 'SUNPASS ZZ TOLL 0042 OCALA FL');
  ${N_OPCION('pj2', "z.o->>'llamar' = 'fn_banco_duplicado' and z.o->'args'->>'p_es_el_mismo' = 'false'")}
  perform pg_temp.paso('inicio', format('select jsonb_build_object(''opcion'', %s)', t));
  perform pg_temp.paso('validar', format($q$select fn_bandeja_validar(%1$L, 'banco', ${OPCION_DE('pj2')})$q$, pg_temp.mov('pj2'), t, pg_temp.mov('pj2')::text));
  perform pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%1$L, 'banco', ${OPCION_DE('pj2')}, '{"fuente":"mas"}')$q$, pg_temp.mov('pj2'), t, pg_temp.mov('pj2')::text));`, true);
{
  const [a, v, h] = guiones.duplicado, nuevas = a.despues.nuevas || [], dup = nuevas.find(x => x.posible_duplicado_de), t0 = dup && a.despues.leer.tarjetas[dup.movimiento_id];
  const f2 = dup && (h.despues.nuevas || []).find(x => x.movimiento_id === dup.movimiento_id), t2 = dup && h.despues.leer.tarjetas[dup.movimiento_id];
  if (!dup || !t0 || !t0.rec || !/^Se parece a otro movimiento/.test(t0.rec.aviso || '') || !(dup.opciones || []).some(o => o.llamar === 'fn_banco_duplicado'))
    throw new Error('guion duplicado: el segundo peaje debía salir como posible duplicado, con sus dos botones: ' + JSON.stringify([dup && dup.opciones, t0]).slice(0, 500));
  if (v.resp.ok !== true || !/^Es otro movimiento/.test(v.resp.texto || '') || h.resp.hecho !== false || h.resp.cambio !== true || h.resp.anotado !== true || !/^Anotado: es otro movimiento/.test(h.resp.por_que || ''))
    throw new Error('guion duplicado: «Es otro movimiento» debía quedar anotado y decirlo (cambio, anotado): ' + JSON.stringify([v.resp, h.resp]).slice(0, 400));
  if (!f2 || f2.motivo === 'posible_duplicado' || (f2.opciones || []).some(o => o.llamar === 'fn_banco_duplicado') || !t2 || (t2.rec && /^Se parece a otro movimiento/.test(t2.rec.aviso || '')))
    throw new Error('guion duplicado: después, el banco ya no debía preguntar si es el mismo: ' + JSON.stringify([f2 && f2.motivo, t2]).slice(0, 400));
}
// (quinta vuelta) EL COBRO ANOTADO «DEPOSITADO NETO DE SU COMISIÓN» NO SE RECOMIENDA SI NO LO DEPOSITA UN PROCESADOR: un cheque anotado
// a mano por la ZZ-104 y, después, el Zelle de otra persona por un 2 % menos. El banco lo propone primero («depositado neto de 29.00 de
// comisión»); la tarjeta PREGUNTA (con el cobro que podría ser y cuánto le falta), y el botón del banco, validado, dice sus montos
guiones.cobro_anotado = guion('cobro_anotado', `
  r := pg_temp.pedir($q$select fn_cobro_registrar(jsonb_build_object('fecha', (fn_fecha_miami(now()) - 3)::text, 'monto', '1450.75', 'medio', 'cheque', 'cuenta', '1010',
         'aplicaciones', jsonb_build_array(jsonb_build_object('factura_id', -1900004, 'monto', '1450.75'))))$q$, 'dueno');
  if r ? 'ERROR' then raise exception 'f19-capturar: el cobro anotado no entró: %', r; end if;
  perform pg_temp.llega('zc1', 1, 1421.75, 'ZELLE PAYMENT FROM ZZ PERSONA NUEVA 5544');
  ${N_OPCION('zc1', "z.o->>'llamar' = 'fn_banco_casar_con' and z.o->'args'->'p_con' ? 'comision'")}
  perform pg_temp.paso('inicio', format('select jsonb_build_object(''opcion'', %s)', t));
  perform pg_temp.paso('validar', format($q$select fn_bandeja_validar(%1$L, 'banco', ${OPCION_DE('zc1')})$q$, pg_temp.mov('zc1'), t, pg_temp.mov('zc1')::text));`, true);
{
  const [a, v] = guiones.cobro_anotado, f = (a.despues.nuevas || []).find(x => x.motivo === 'deposito_otro_cobro'), t = f && a.despues.leer.tarjetas[f.movimiento_id];
  if (!f || a.resp.opcion !== 0 || !t || !t.rec || t.rec.accion || t.rec.pill !== '¿Cobro que anotaste?'
      || !/^Este depósito \(\$1,421\.75\) puede ser el del cobro de \$1,450\.75 que anotaste el .*: le faltarían \$29\.00\./.test(t.rec.aviso || ''))
    throw new Error('guion cobro_anotado: el Zelle al que le falta poco respecto de un cheque anotado debía PREGUNTAR (no recomendar casarlo): ' + JSON.stringify([f && f.motivo, a.resp, t]).slice(0, 600));
  if (v.resp.ok !== true || !/llegaron \$1,421\.75, y los \$29\.00 que faltan se registran como la comisión del procesador de tarjetas\.$/.test(v.resp.texto || ''))
    throw new Error('guion cobro_anotado: el botón «depositado neto» debía decir sus montos: ' + JSON.stringify(v.resp).slice(0, 400));
}
// (quinta vuelta) UN ABONO EN LA TARJETA (la devolución de una compra, que el banco no dice que sea un pago): el banco ofrece «Fue un
// pago a la tarjeta desde <cuenta>» por cada cuenta propia, también desde la de paso de Stripe (que la pantalla esconde): otro caso de
// botones corridos; y sus botones decían la cuenta por su código («desde 1010»)
guiones.abono = guion('abono', `
  ${DUENO_ES}
  perform fn_banco_importar_filas(jsonb_build_object('origen', 'plaid', 'cuenta', '2100-2013', 'nombre', 'Plaid · f19-capturar · ab1',
    'filas', jsonb_build_array(jsonb_build_object('id', 'ZZ19-ab1', 'fecha', (fn_fecha_miami(now()) - 1)::text, 'plaid_monto', '-45.10',
             'descripcion', 'ZZ FERRETERIA DEL NORTE #6341 OCALA FL', 'tipo', 'CREDIT', 'pendiente', false))));
  perform fn_banco_casar((select m.id from movimientos_banco m where m.id_externo = 'ZZ19-ab1' order by m.importado_el desc limit 1));
  ${NADIE_ES}
  insert into public.f19_semilla (clave, movimiento, nota)
  select 'ab1', m.id, 'un abono en la tarjeta' from movimientos_banco m where m.id_externo = 'ZZ19-ab1' order by m.importado_el desc limit 1;
  perform pg_temp.paso('inicio', 'select null::jsonb');`, true);
{
  const [a] = guiones.abono, f = (a.despues.nuevas || []).find(x => x.motivo === 'abono_tarjeta'), t = f && a.despues.leer.tarjetas[f.movimiento_id];
  const ops = (f && f.opciones) || [];
  if (!f || !t || ops.length < 3 || !ops.every(o => o.llamar === 'fn_banco_transferencia' && /desde \d{4}/.test(o.texto)) || (ops[1].args || {}).p_cuenta !== '1020' || (t.ops || []).length !== ops.length)
    throw new Error('guion abono: el abono en la tarjeta debía traer «Fue un pago a la tarjeta desde <cuenta>» por cada cuenta propia, con la de Stripe en medio: ' + JSON.stringify([f && f.motivo, ops.map(o => o.texto)]).slice(0, 500));
}
console.log(`  ${Object.keys(guiones).length} guiones: ${Object.entries(guiones).map(([k, v]) => `${k} (${v.length})`).join(', ')}`);

// (cuarta vuelta) LO QUE SE REGISTRA POR EL CAMINO DE ANTES dentro de «Más opciones» («Otra cosa… → clasificarlo a una cuenta»: la
// puerta de siempre del banco) y la Bandeja ANOTA después (fn_bandeja_anotar con {fuente: "mas"}: no toca el libro): queda en «Lo que
// contestaste estos días», con su texto llano, y se puede deshacer
const masViejo = (() => {
  const [cl, sinRastro, an, l, q, des] = pedir([
    { sql: `select fn_banco_clasificar('${ids.kl1}', '[{"cuenta": "6500"}]'::jsonb, null)` },
    { quien: 'editor', sql: `select to_jsonb((select count(*) from bandeja_hechos h where h.movimiento_id = '${ids.kl1}'))` },
    { sql: `select fn_bandeja_anotar('${ids.kl1}', ${j({ fuente: 'mas' })})` }, LEER, IDS,
    { sql: `select fn_bandeja_deshacer((select h.id from bandeja_hechos h where h.movimiento_id = '${ids.kl1}' and h.deshecho_el is null), 'no era eso')` }]);
  sano(cl, 'el camino de antes: clasificar'); sano(an, 'el camino de antes: anotar'); sano(des, 'el camino de antes: deshacer');
  if (Number(sinRastro) !== 0 || an.hecho !== true || an.recordado || !/^Es un gasto de «Oficina y software»: \$45\.00\.$/.test(an.texto || '') || !(l.recientes || []).some(h => h.hecho_id === an.hecho_id) || q.includes(ids.kl1) || des.deshecho !== true)
    throw new Error('el camino de antes: clasificar no debía dejar rastro en la Bandeja, y anotarlo sí (en llano, y con su «Deshacer»): ' + JSON.stringify([sinRastro, an, des]).slice(0, 500));
  return { movimiento: ids.kl1, clasificar: cl, anotar: an, despues: { ids: q, leer: resto(l) } };
})();
console.log('  el camino de antes («Otra cosa…»), anotado por la Bandeja');

// LA CADENA de lo que entra solo (una sola transacción: cada paso ve lo del anterior)
const cadena = (() => {
  const PASOS = [
    ['grupo_solo', () => grupo('C:NETFLIX', 'personal', {}, { movimientos: movsDe('C:NETFLIX'), recordar: true, solo: true })],
    ['llega', () => ({ sql: `select pg_temp.llega('nf3', 1, -15.49, 'NETFLIX.COM')`, quien: 'editor' })],
    ['entra_solo', () => ({ sql: `select fn_bandeja_solo(${j({ corrio: 'pantalla' })})` })],
    ['deshacer', null],
    // (tercera vuelta) deshacer lo que entró solo APAGA la regla (lo hace la base): el cargo que llega después espera
    ['llega2', () => ({ sql: `select pg_temp.llega('nf4', 1, -15.49, 'NETFLIX.COM')`, quien: 'editor' })],
    ['no_entra', () => ({ sql: `select fn_bandeja_solo(${j({ corrio: 'pantalla' })})` })],
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
  if (de('deshacer').resp.deshecho !== true || de('deshacer').resp.solo_apagado !== 'NETFLIX') throw new Error('cadena: no se deshizo, o no apagó «entra solo» de Netflix: ' + JSON.stringify(de('deshacer').resp));
  if ((de('no_entra').resp.registrados || []).length || de('no_entra').despues.filas.length !== de('deshacer').despues.filas.length + 1) throw new Error('cadena: el cargo que llegó después de deshacer debía esperar: ' + JSON.stringify(de('no_entra').resp));
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
{
  // (g) (tercera vuelta) un comercio cuyo nombre es una sola palabra larguísima: lo que entendió el «Dímelo» lleva ese nombre en
  // sus casillas («Recordarlo: lo próximo de …»), y la tarjeta tiene que caber igual
  const frase = 'son cables y conectores para el taller', ia = { accion: 'gasto', cuenta: '6400', recordar: true, explicacion: 'Una compra a una distribuidora de material eléctrico menor.' };
  const [g] = pedir([guardar(ids.lg1, frase, ia)]);
  if (sano(g, 'dimelo larga').estado !== 'pendiente' || !/^[A-Z]{40,}$/.test(leer.tarjetas[ids.lg1].nombre || '')) throw new Error('dimelo: el comercio de nombre largo debía quedar con su propuesta pendiente: ' + JSON.stringify([g, leer.tarjetas[ids.lg1]]).slice(0, 300));
  dimelo.larga = { movimiento: ids.lg1, frase, ia, guardado: g };
}
{
  // (h) (sexta vuelta, 6b) LA LÍNEA DE CRÉDITO EN LA PANTALLA. En un guion (una transacción que se deshace): se da de alta una línea
  // de crédito de un prestamista inventado («ZZ Banco», que no es de la lista de marcas: lo demás de la semilla no cambia) y llegan
  // dos pagos suyos y un desembolso. La tarjeta del pago dice que es de la línea (`linea`), que no se recuerda (`no_recordar`) y pide
  // sus intereses; los dos pagos NO forman un grupo; el primero se registra con «Así es» y sus intereses; y el segundo por el
  // «Dímelo»: lo que la base guarda dice qué pide (los intereses), también cuando la Bandeja se lee otra vez, y se aprueba con ellos
  const frase = 'es el pago de la linea de credito', ia = { accion: 'prestamo', prestamista: 'ZZ Banco', recordar: true, explicacion: 'Dices que es el pago de la línea de crédito.' };
  const guardarFmt = `select fn_bandeja_dimelo_guardar(%1$L, '${DUENO}', ${dolar(frase)}, false,
    (select jsonb_build_object('movimiento', k->'movimiento', 'lo_que_dice_edgar', k->'frase') from (select fn_bandeja_dimelo_contexto(%1$L, '${DUENO}', ${dolar(frase)}) as k) z),
    '{}'::jsonb, ${j(ia)}, 'claude-opus-5-5', 'medium', 'f19-capturar', ${j(U)})`;
  guiones.linea = guion('linea', `
    perform fn_bandeja_linea('{"nombre": "ZZ Banco", "descriptor": "\\\\mZZBANCO LINEA\\\\M"}');
    perform pg_temp.llega('ln1', 2, -1000.00, 'ACH ZZBANCO LINEA PAGO ZZ31');
    perform pg_temp.llega('ln2', 1, -500.00, 'ACH ZZBANCO LINEA PAGO ZZ32');
    perform pg_temp.llega('ln3', 1, 3000.00, 'ACH ZZBANCO LINEA ADVANCE ZZ33');
    perform pg_temp.paso('inicio', 'select null::jsonb');
    r := pg_temp.pedir(format('select fn_bandeja_recomendar(%L)', pg_temp.mov('ln1')), 'dueno');
    perform pg_temp.paso('hacer', format($q$select fn_bandeja_hacer(%L, 'prestamo', %L::jsonb, '{"fuente":"recomendacion"}')$q$, pg_temp.mov('ln1'),
              (r->'datos') || '{"campos":{"p_interes":"61.37"}}'::jsonb));
    r := pg_temp.paso('guardar', format(${dolar(guardarFmt)}, pg_temp.mov('ln2')), 'editor');
    perform pg_temp.paso('aprobar', format($q$select fn_bandeja_aprobar(%L, '{"campos":{"p_interes":"12.50"}}'::jsonb)$q$, r->>'dimelo_id'));`, true);
  const [a, h, g, ap] = guiones.linea, nuevas = a.despues.nuevas || [], de = n => nuevas.find(x => Number(x.monto) === n);
  const p1 = de(-1000), p2 = de(-500), ds = de(3000), t1 = p1 && a.despues.leer.tarjetas[p1.movimiento_id], td = ds && a.despues.leer.tarjetas[ds.movimiento_id];
  if (!p1 || !p2 || !ds || !t1 || t1.linea !== true || t1.no_recordar !== true || t1.sabe !== 'prestamista' || !t1.rec || t1.rec.accion !== 'prestamo'
      || JSON.stringify(t1.rec.pide) !== '["p_interes"]' || !/^Es un pago a tu línea de crédito de ZZ Banco: \$1,000\.00\. Pon abajo cuánto de este pago fueron intereses/.test(t1.rec.texto || ''))
    throw new Error('guion linea: el pago de la línea debía decirse de la línea (linea, no_recordar), recomendarse y pedir sus intereses: ' + JSON.stringify(t1).slice(0, 600));
  if ((a.despues.leer.grupos || LEER0.grupos || []).some(x => (x.movimientos || []).some(id => id === p1.movimiento_id || id === p2.movimiento_id)))
    throw new Error('guion linea: los dos pagos de la línea no debían formar un grupo: ' + JSON.stringify(a.despues.leer.grupos).slice(0, 500));
  if (!td || td.linea !== true || !td.rec || td.rec.accion !== 'prestamo' || !/^Es dinero de tu línea de crédito de ZZ Banco: \$3,000\.00/.test(td.rec.texto || ''))
    throw new Error('guion linea: el desembolso debía recomendarse como dinero de la línea: ' + JSON.stringify(td).slice(0, 400));
  if (h.resp.hecho !== true || h.resp.texto !== 'Es un pago a tu línea de crédito de ZZ Banco: $1,000.00 ($938.63 bajan lo que debes en la línea y $61.37 son intereses).' || h.resp.recordado)
    throw new Error('guion linea: el pago con sus intereses debía registrarse, y sin recordar nada: ' + JSON.stringify(h.resp).slice(0, 400));
  const dg = g.despues.leer.tarjetas[p2.movimiento_id].dimelo;
  if (g.resp.estado !== 'pendiente' || g.resp.accion !== 'prestamo' || JSON.stringify(g.resp.pide) !== '["p_interes"]' || !dg || JSON.stringify(dg.pide) !== '["p_interes"]')
    throw new Error('guion linea: lo que entendió el «Dímelo» del pago de la línea debía quedar pendiente diciendo qué pide, también al leer otra vez: ' + JSON.stringify([g.resp, dg]).slice(0, 600));
  if (ap.resp.hecho !== true || !/\$487\.50 bajan lo que debes en la línea y \$12\.50 son intereses/.test(ap.resp.texto || ''))
    throw new Error('guion linea: aprobada con sus intereses debía registrarse: ' + JSON.stringify(ap.resp).slice(0, 400));
  dimelo.linea = { movimiento: p2.movimiento_id, frase, ia, guardado: g.resp, aprobar: { resp: ap.resp, despues: ap.despues } };
}
console.log(`  «Dímelo»: ${Object.keys(dimelo).length} casos`);

// LAS PROPUESTAS DE LA IA DE ANTES (c8), aprobadas por SU puerta (lo que hace la función de borde «contador» con «aprobar») y,
// tercera vuelta, ANOTADAS por la Bandeja (fn_bandeja_anotar, como el dueño): el gasto general, lo personal y el gasto de obra con
// la obra que Edgar deja en la tarjeta. Quedan en «Lo que contestaste estos días», recordadas, y se pueden deshacer (lo aprobado
// por c8 vuelve entonces para caducarlo)
const iaUna = (k, obra, op) => {
  const prop = propDe(k);
  const [a, sinRastro, an, l, q, an2, des, l2] = pedir([
    { quien: 'editor', sql: `select fn_contador_aprobar('${prop}', '${DUENO}', ${obra ? `'${obra}'` : 'null'}, true)` },
    { quien: 'editor', sql: `select to_jsonb((select count(*) from bandeja_hechos h where h.movimiento_id = '${ids[k]}'))` },
    { sql: `select fn_bandeja_anotar('${ids[k]}', ${j(op)})` }, LEER, IDS,
    { sql: `select fn_bandeja_anotar('${ids[k]}', ${j(op)})` },
    { sql: `select fn_bandeja_deshacer((select h.id from bandeja_hechos h where h.movimiento_id = '${ids[k]}' and h.deshecho_el is null), 'no era eso')` }, LEER]);
  sano(a, 'fn_contador_aprobar ' + k); sano(an, 'fn_bandeja_anotar ' + k); sano(des, 'deshacer lo anotado ' + k);
  if (Number(sinRastro) !== 0 || an.hecho !== true || an2.hecho_id !== an.hecho_id || !(l.recientes || []).some(h => h.hecho_id === an.hecho_id)) throw new Error(`c8 ${k}: aprobar no debía dejar rastro en la Bandeja, y anotar sí (una sola vez): ` + JSON.stringify([sinRastro, an, an2]).slice(0, 400));
  if (/\b\d{4}\b/.test(String(an.texto).replace(/\$[\d,.]+/g, '')) || des.deshecho !== true || !(des.ia_caducar || []).includes(prop) || !(l2.ia_caducar || []).includes(prop)) throw new Error(`c8 ${k}: lo anotado debía decirse en llano y, al deshacerlo, devolver la propuesta para caducarla: ` + JSON.stringify([an, des]).slice(0, 400));
  return { clave: k, propuesta: prop, movimiento: ids[k], obra: obra || null, resp: a, anotar: an, despues: { ids: q, leer: resto(l) }, deshacer: { resp: des, leer: resto(l2) } };
};
const iaAprobar = iaUna('fe1', null, { recordar: true, solo: false });
const iaMas = { ia2: iaUna('ia2', null, { recordar: true, solo: true }), ia3: iaUna('ia3', 'oficina-nch-7xq2', { recordar: true, solo: false }) };
if (!(iaMas.ia2.anotar.recordado || {}).solo || !/^Es tuyo, no de la empresa/.test(iaMas.ia2.anotar.texto) || !/ZZ Oficina Norte/.test(iaMas.ia3.anotar.texto)) throw new Error('c8: lo personal debía quedar recordado con «entra solo», y el gasto de obra con su obra: ' + JSON.stringify([iaMas.ia2.anotar, iaMas.ia3.anotar]).slice(0, 500));
console.log('  las tres propuestas de la IA de antes: aprobadas por su puerta, anotadas y deshechas');

// (tercera vuelta) LA BANDEJA LEÍDA POR PARTES: con el reloj corto (aquí, «max»: unas pocas recomendaciones por llamada, que es lo
// que el reloj hace con una Bandeja de cientos) la primera lectura trae unas tarjetas y deja las demás «pensando», en «faltan»; la
// pantalla las pide con {ids: faltan} hasta que no falta ninguna
const partes = (() => {
  const [p0] = pedir([{ sql: `select fn_bandeja_leer(${j({ max: 6 })})` }]);
  sano(p0, 'leer por partes');
  const [p1] = pedir([{ sql: `select fn_bandeja_leer(${j({ ids: p0.faltan, max: 10 })})` }]);
  sano(p1, 'la segunda parte');
  const [p2] = pedir([{ sql: `select fn_bandeja_leer(${j({ ids: p1.faltan })})` }]);
  sano(p2, 'la tercera parte');
  const pens = Object.values(p0.tarjetas).filter(t => t.pensando).length;
  if (p0.parcial !== true || !p0.faltan.length || pens !== p0.faltan.length || !(p0.grupos || []).some(g => g.pendiente) || !(p0.grupos || []).some(g => !g.pendiente && g.rec)) throw new Error('leer por partes: la primera debía traer unas recomendaciones, y lo demás «pensando» y en «faltan», con algún grupo pendiente: ' + JSON.stringify({ parcial: p0.parcial, faltan: p0.faltan.length, pens }));
  if (p1.parte !== true || !p1.faltan.length || p1.faltan.length >= p0.faltan.length || p2.faltan.length || p2.parcial) throw new Error('leer por partes: cada parte debía avanzar y la última no dejar nada: ' + JSON.stringify([p0.faltan.length, p1.faltan.length, p2.faltan.length]));
  // juntas, las tres partes dicen lo mismo que la lectura entera
  const tj = { ...p0.tarjetas, ...p1.tarjetas, ...p2.tarjetas };
  for (const id of Object.keys(leer.tarjetas)) if (JSON.stringify(tj[id]) !== JSON.stringify(leer.tarjetas[id])) throw new Error('leer por partes: la tarjeta de ' + id + ' no quedó como en la lectura entera: ' + JSON.stringify([tj[id], leer.tarjetas[id]]).slice(0, 400));
  return [p0, p1, p2];
})();
console.log(`  la lectura por partes: ${partes.map(p => Object.keys(p.tarjetas).length + ' tarjetas, faltan ' + p.faltan.length).join(' → ')}`);

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
  // (tercera vuelta) LAS COMIDAS: la semilla deja una ya en el libro; el paquete la lleva en su línea (la 26 del 1120, la 20 del
  // 1120-S) al 100 % de libros, con su mitad no deducible dicha en el renglón de la cuenta y en un aviso
  const comida = pq => (pq.tax_lines || []).flatMap(t => (t.accounts || []).map(a => ({ ...a, line: t.line }))).find(a => a.account === '6350');
  for (const [pq, linea] of [[p, '26'], [p2, '20']]) {
    const a = comida(pq);
    if (!a || a.line !== linea || !(Number(a.amount) > 0) || Number(a.deductible) + Number(a.nondeductible) !== Number(a.amount) || !/only 50% is deductible/i.test(a.note || '') || !(pq.warnings || []).some(w => /^MEALS: account 6350/.test(w)))
      throw new Error(`fiscal: las comidas debían salir en la línea ${linea} con su nota y su aviso: ` + JSON.stringify(a));
  }
  if (!etq || Object.keys(etq).length < 5) throw new Error('fiscal: las vistas de los estados debían traer sus nombres en inglés: ' + JSON.stringify(etq));
  // (cuarta vuelta) LA BALANZA DEL SEGUNDO EJERCICIO: el libro no postea asientos de cierre, así que en el año siguiente el resultado
  // de este va en un renglón aparte de la balanza (no es una cuenta), con él la balanza suma 0 y es la de los estados, y el paquete
  // lo explica arriba. Y la balanza de este año, con sus totales
  const [ps] = pedir([{ sql: `select fn_fiscal_paquete(${anio + 1}, null)` }]);
  sano(ps, 'fiscal siguiente');
  const comp = (ps.trial_balance || []).filter(x => !x.account), tt = ps.trial_balance_totals || {}, suma = k => (ps.trial_balance || []).reduce((s2, x) => s2 + Math.round(Number(x[k] || 0) * 100), 0);
  if (!comp.length || !comp.every(x => x.level === 'component' && x.name && x.note && x.tax_line) || tt.balanced !== true || suma('ending') !== 0 || suma('beginning') !== 0 || Number(tt.ending) !== 0
      || !(ps.warnings || []).some(w => /^NO CLOSING ENTRIES ARE POSTED/.test(w)) || (ps.trial_balance || []).filter(x => x.account).reduce((s2, x) => s2 + Math.round(Number(x.ending || 0) * 100), 0) === 0)
    throw new Error('fiscal: el paquete del año siguiente debía traer el renglón del resultado de años anteriores (sin él las cuentas no suman 0), sus totales en cero y su aviso: ' + JSON.stringify([comp, tt]).slice(0, 600));
  if (!p.trial_balance_totals || p.trial_balance_totals.balanced !== true || (p.trial_balance || []).some(x => !x.account)) throw new Error('fiscal: la balanza del primer año debía cuadrar sin renglones de más: ' + JSON.stringify(p.trial_balance_totals));
  return { anio, leer: l, paquete: p, a_1120s: { resp: f, leer: l2, paquete: p2 }, confirmada: { resp: c, leer: l3, paquete: p3 }, fuera: { anio: anio - 1, paquete: pf }, siguiente: { anio: anio + 1, paquete: ps }, etiquetas: etq };
})();
console.log('  lo fiscal: el paquete con el 1120, con el 1120-S y confirmado');

// ---------- 3. que no salga nada de verdad ----------
const out = {
  que: 'La base simulada de la Bandeja nueva (c17) y de las cuentas en inglés (c18), sacada del banco de pruebas por pruebas/conta/f19-capturar.js: cada respuesta es la que dio la base, como el dueño.',
  capturado: psql('select fn_fecha_miami(now())').trim(), plantilla: PLANTILLA,
  huellas: { 'docs/conta/c17-bandeja.sql': huella('docs/conta/c17-bandeja.sql'), 'docs/conta/c18-fiscal.sql': huella('docs/conta/c18-fiscal.sql'), [SEMILLA]: huella(SEMILLA) },
  dueno: DUENO, ids, propuesta_ia: propIA, cuentas, proyectos, bandeja, leer, facturas, validar, sueltas, grupo_depositos: grupoDep, guiones, cadena, dimelo, ia_aprobar: iaAprobar, ia_mas: iaMas, mas_viejo: masViejo, partes, fiscal
};
const texto = JSON.stringify(out, null, 1);
const sinIds = texto.replace(/casa-perez-k3m9|oficina-nch-7xq2|taller-ruiz-5b2n/g, '');
const malo = /p[eé]rez|\bnch\b|ruiz|gustavo|\bpedro\b|edgar@|@(?!example\.com)[a-z0-9-]+\.(com|net|org)/i.exec(sinIds);
if (malo) throw new Error(`en lo capturado sale «${malo[0]}»: la semilla tiene que dejarlo todo «ZZ» (${sinIds.slice(Math.max(0, malo.index - 80), malo.index + 80)})`);
fs.writeFileSync(SALIDA, texto + '\n');
console.log(`escrito ${path.relative(ROOT, SALIDA)} (${Math.round(texto.length / 1024)} KB): ${bandeja.length} movimientos, ${Object.keys(sueltas).length} acciones sueltas, ${Object.keys(guiones).length} guiones, ${cadena.length} pasos de la cadena, ${Object.keys(dimelo).length} del «Dímelo»`);
