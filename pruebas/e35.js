/* E35 · Tanda 1 de Mariners (23/09): lo que no es material ya no paga como
   material, el takeoff cuadra, el permiso lo saca quien lo saca, ICRA en modo
   planos, el flete de la cuota no se tira y la validez de la propuesta se puede
   cambiar.
   Lo primero, siempre: que NINGÚN estimado que ya existe se mueva un centavo.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e35.js          */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };
const srv = http.createServer((req, res) => {
  let p = req.url.split('?')[0]; if (p === '/') p = '/index.html';
  fs.readFile(path.join(ROOT, p), (e, d) => {
    if (e) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d);
  });
});
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));
const CAT = [
  { id: 1, item: 'CAJA', seccion: 'RACEWAY', precio: 10, horas_unidad: 0.5 },
  { id: 2, item: 'PERMISO E INSPECCIONES (por proyecto)', unidad: 'E', precio: 0, horas_unidad: 6, codigo: '20-MISC' },
  { id: 3, item: 'BARRERA ICRA / CONTENCIÓN DE POLVO (por barrera)', unidad: 'E', precio: 0, horas_unidad: 4, codigo: '01-DEMO' },
];
const ESC = [{ id: 'B', foreman: 43, journeyman: 34, helper: 22, pct_foreman: .2, pct_journeyman: .5,
               pct_helper: .3, benefits: .25, tax_material: .075, overhead_hh: 30.19, profit: .12 },
             { id: 'P', foreman: 43, journeyman: 34, helper: 22, pct_foreman: .2, pct_journeyman: .5,
               pct_helper: .3, benefits: .25, tax_material: .065, overhead_hh: 0, overhead_pct: 0.15, profit: .10 }];
const CFG = { misc_pct: 0.03 };
const r2 = v => Math.round(v * 100) / 100;
const cerca = (a, b) => Math.abs(a - b) < 0.011;

(async () => {
  await new Promise(r => srv.listen(8866, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8866/index.html'); await p.waitForTimeout(500);
  const ITEMS = [{ id: 1, estimado_id: 7, item: 'CAJA', cantidad: 100, precio: 10, horas: 0.5, unidad: 'EA', orden: 1 }];
  await p.evaluate(([c, e, cf, it]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] }), [CAT, ESC, CFG, ITEMS]);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);
  const BASE = { id: 7, nombre: 'Mariners Hospital Chillers Replacement', escenario: 'B', modo: 'planos', estado: 'borrador', factor: 1 };

  /* === 1. lo de siempre no se mueve === */
  const viejo = await calc({ ...BASE, lineas_material: [{ desc: 'Cable', monto: 3000 }, { desc: 'SG', monto: 48000, tipo: 'cot' }] });
  const esperado = (() => {   // la fórmula de antes, a mano
    const propio = 1000 + 3000, misc = propio * .03, mat = propio + 48000 + misc, tax = mat * .075;
    const merma = 0; const labor = 50 * (43 * .2 + 34 * .5 + 22 * .3) * 1.25, prime = labor + mat + tax + merma, oh = 50 * 30.19;
    return prime + oh + (prime + oh) * .12;
  })();
  ok('material tuyo + cotización: el bid es EXACTAMENTE el de la fórmula de antes', cerca(viejo.bid, esperado), r2(viejo.bid) + ' vs ' + r2(esperado));
  ok('sin líneas de costo, costos = 0 y la hora cargada es bid ÷ horas como siempre', viejo.costos === 0 && cerca(viejo.tarifaCargada, viejo.bid / viejo.horas), r2(viejo.tarifaCargada));

  /* === 2. logística: sin tax, sin misceláneas, sin markup === */
  const sin = await calc({ ...BASE, markup_pct: 0.10 });
  const con = await calc({ ...BASE, markup_pct: 0.10, lineas_material: [{ desc: 'Hotel y per diem — Cayos', monto: 10000, tipo: 'log' }] });
  ok('una línea de LOGÍSTICA no toca el material, ni el tax, ni las misceláneas, ni el markup',
    cerca(con.totalMaterial, sin.totalMaterial) && cerca(con.tax, sin.tax) && cerca(con.misc, sin.misc) && cerca(con.markup, sin.markup), r2(con.totalMaterial));
  ok('con overhead por hora, entra al bid con su profit y nada más: $10.000 × 1,12', cerca(con.bid - sin.bid, 11200), r2(con.bid - sin.bid));
  ok('la hora cargada no se envenena con los dólares de viaje', cerca(con.tarifaCargada, sin.tarifaCargada), r2(con.tarifaCargada) + ' vs ' + r2(sin.tarifaCargada));
  const vieja = await calc({ ...BASE, markup_pct: 0.10, lineas_material: [{ desc: 'Hotel y per diem — Cayos', monto: 10000 }] });
  ok('la misma línea SIN marcar sigue como antes (paga tax y misceláneas): el cambio es opt-in', vieja.tax > con.tax && vieja.bid > con.bid, '$' + r2(vieja.bid - con.bid) + ' de más sin marcar');

  /* === 3. overhead por porcentaje: allowance y subcontrato llevan overhead === */
  const sinP = await calc({ ...BASE, escenario: 'P' });
  const conP = await calc({ ...BASE, escenario: 'P', lineas_material: [{ desc: 'Fire alarm vendor', monto: 9500, tipo: 'allow' }, { desc: 'Cuadrilla Miami', monto: 34000, tipo: 'sub' }] });
  ok('con overhead por %, los costos directos llevan overhead y profit: 43.500 × 1,15 × 1,10', cerca(conP.bid - sinP.bid, 43500 * 1.15 * 1.10), r2(conP.bid - sinP.bid));
  ok('y la hora cargada sigue igual', cerca(conP.tarifaCargada, sinP.tarifaCargada), r2(conP.tarifaCargada));

  /* === 4. escalación: no escala el per diem === */
  const escSin = await calc({ ...BASE, meses_obra: 18, escalacion_pct: 0.04 });
  const escCon = await calc({ ...BASE, meses_obra: 18, escalacion_pct: 0.04, lineas_material: [{ desc: 'Per diem', monto: 32000, tipo: 'log' }] });
  ok('la escalación no se cobra sobre la logística', cerca(escCon.escalacion, escSin.escalacion), r2(escCon.escalacion));

  /* === 5. el takeoff cuadra === */
  const ESTT = { ...BASE, markup_pct: 0.05, meses_obra: 12, escalacion_pct: 0.04, lineas_material: [
    { desc: 'Cable a mano', monto: 2000 }, { desc: 'Switchgear', monto: 20000, tipo: 'cot' },
    { desc: 'Hotel y per diem', monto: 5531, tipo: 'log' }, { desc: 'Fire alarm vendor', monto: 9500, tipo: 'allow' }] };
  const cT = await calc(ESTT);
  const txt = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.takeoff(e, c), [ESTT, cT]);
  const filas = txt.split('\n').map(x => x.split('\t'));
  const val = nombre => { const f = filas.find(x => x[1] === nombre); return f ? Number(f[7]) : NaN; };
  const cabecera = filas.findIndex(x => x[0] === 'Partida');
  const blanco = filas.findIndex((x, i) => i > cabecera && x.length === 1 && x[0] === '');
  const renglones = filas.slice(cabecera + 1, blanco).reduce((s, x) => s + Number(x[7]), 0);
  const sumaMat = renglones + (val('+ Merma (cable / tubería)') || 0) + (val('+ Misceláneas') || 0) + (val('+ Sales tax') || 0) + (val('+ Markup de materiales') || 0);
  ok('los renglones + merma + misceláneas + tax + markup suman el «= MATERIAL»', Math.abs(sumaMat - val('= MATERIAL')) < 0.05, r2(sumaMat) + ' vs ' + val('= MATERIAL'));
  ok('las líneas a mano de material y cotización salen como renglón', /Cable a mano\ta mano\t/.test(txt) && /Switchgear\ta mano · cotización/.test(txt));
  ok('la logística y el allowance salen en su bloque de COSTOS DIRECTOS, con su total', /COSTOS DIRECTOS/.test(txt) && cerca(val('= COSTOS DIRECTOS'), 15031), val('= COSTOS DIRECTOS'));
  const cuadre = val('= MATERIAL') + val('Mano de obra (' + cT.tarifaCargada.toFixed(2) + '/h cargada)') + (val('+ Escalación (12 meses de obra)') || 0) + val('= COSTOS DIRECTOS') + val('Overhead') + val('Profit');
  ok('y de arriba abajo el takeoff suma el TOTAL', Math.abs(cuadre - val('TOTAL')) < 0.06, r2(cuadre) + ' vs ' + val('TOTAL'));

  /* === 6. la propuesta: allowances a la vista, logística no; validez editable === */
  const prop = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propuesta(e, c), [ESTT, cT]);
  ok('el ALLOWANCE sale nombrado con su monto', /ALLOWANCES INCLUIDOS[\s\S]*Fire alarm vendor: \$9,500\.00/.test(prop));
  ok('la logística NO se nombra en un lump sum', !/Hotel y per diem/.test(prop));
  ok('sin decir nada, la propuesta sigue válida por 15 días', /válida por 15 días/.test(prop));
  const prop7 = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propuesta(e, c), [{ ...ESTT, valida_dias: 7 }, cT]);
  ok('con valida_dias = 7, dice 7 días', /válida por 7 días/.test(prop7));
  const mep = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.mep(e, c), [ESTT, cT]);
  ok('el resumen de MXP MEP dice los costos directos', /Logística \/ allowances \/ subs:\s+\$15,031\.00/.test(mep), (mep.match(/Logística.*$/m) || [''])[0]);

  /* === 7. la cuota: el flete no se tira y el importe único se avisa === */
  const cuota = await p.evaluate(() => window.MXP_PRUEBA.e0.leeCuota(
    '3  600A SWITCHBOARD SECTION   $74,550.00\n12  LITHONIA STAK 2X2 5000LM   $168.40   $2,020.80\nFREIGHT / DELIVERY TO KEY LARGO   $1,450.00\nSUBTOTAL  $76,570.80'));
  ok('el flete se lee con su monto', cuota.flete.length === 1 && cuota.flete[0].monto === 1450, JSON.stringify(cuota.flete));
  const sw = cuota.filas.find(f => /SWITCHBOARD/.test(f.desc)), lu = cuota.filas.find(f => /STAK/.test(f.desc));
  ok('una línea con UN solo importe y 3 unidades queda marcada, con lo que sería cada una si es el total', sw && sw.unImporte && sw.siTotal === 24850, sw && sw.siTotal);
  ok('una línea con unitario y extendido no se marca', lu && !lu.unImporte && lu.precio === 168.4);
  ok('el subtotal sigue sin colarse como renglón', !cuota.filas.some(f => /SUBTOTAL/.test(f.desc)));

  /* === 8. el permiso lo saca quien lo saca; ICRA en modo planos === */
  const h = est => p.evaluate(e => window.MXP_PRUEBA.e0.horas([], e, {}), est);
  const permiso = r => r.filas.find(f => f.id === 'permiso');
  const directo = await h({ ...BASE });
  const conGC = await h({ ...BASE, contratista_id: 'wisdom' });
  const deMEP = await h({ ...BASE, empresa: 'mep' });
  ok('trato directo: el permiso sale marcado como siempre', permiso(directo) && !permiso(directo).supuesto);
  ok('con un contratista: el permiso sale SIN marcar y lo dice', permiso(conGC) && permiso(conGC).supuesto && /GC/.test(permiso(conGC).de));
  ok('en un trabajo de MXP MEP: tampoco se marca', permiso(deMEP) && permiso(deMEP).supuesto);
  ok('en modo planos, en un hospital, ya se propone la barrera ICRA', directo.filas.some(f => f.id === 'icra'));
  const obraNueva = await h({ ...BASE, nombre: 'Wimauma Ball Field — 480V Panel' });
  ok('en modo planos, en una obra que no es de salud, no', !obraNueva.filas.some(f => f.id === 'icra'));

  /* === 9. el panel de líneas a mano se pinta con el tipo de cada una === */
  const html = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.mano(e, c), [ESTT, cT]);
  ok('cada línea trae su selector con el tipo elegido', (html.match(/rap-mat-tipo/g) || []).length === 8 && /value="log" selected/.test(html) && /value="allow" selected/.test(html) && /value="cot" selected/.test(html));
  ok('y su chip: LOGÍSTICA, ALLOWANCE, COTIZACIÓN', /LOGÍSTICA<\/span>/.test(html) && /ALLOWANCE<\/span>/.test(html) && /COTIZACIÓN<\/span>/.test(html));
  ok('el total de material a mano no mete la logística', /Material a mano — \$22,000\.00/.test(html) && /\$15,031\.00 en logística/.test(html));

  ok('sin errores de consola', errs.length === 0, errs.join(' // ').slice(0, 200));
  console.log(R.join('\n'));
  const fails = R.filter(l => l.indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - fails) + '/' + R.length + ' ok');
  await b.close(); srv.close(); process.exit(fails ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
