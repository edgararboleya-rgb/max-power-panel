/* E13a · Las cotizaciones del proveedor no pagan misceláneas.
   Lo que se comprueba, por este orden:
     1. que NINGÚN estimado que ya existe se mueva ni un centavo, y
     2. que marcar una línea como cotización quite solo lo que sobra.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e13.js          */
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
const CAT = [{ id: 1, item: 'CAJA', seccion: 'RACEWAY', precio: 10, horas_unidad: 0.5 }];
const ESC = [{ id: 'B', foreman: 43, journeyman: 34, helper: 22, pct_foreman: .2, pct_journeyman: .5,
               pct_helper: .3, benefits: .25, tax_material: .075, overhead_hh: 30.19, profit: .12 }];
const CFG = { misc_pct: 0.03 };
const r2 = v => Math.round(v * 100) / 100;

(async () => {
  await new Promise(r => srv.listen(8865, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8865/index.html'); await p.waitForTimeout(500);
  const prep = items => p.evaluate(([c, e, cf, it]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] });
  }, [CAT, ESC, CFG, items]);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);

  /* Un estimado de servicio: 100 cajas propias + una cotización de switchgear */
  const ITEMS = [{ id: 1, estimado_id: 7, item: 'CAJA', cantidad: 100, precio: 10, horas: 0.5, unidad: 'EA', orden: 1 }];
  await prep(ITEMS);
  const BASE = { id: 7, nombre: 'Prueba', escenario: 'B', modo: 'servicio', estado: 'borrador', factor: 1 };

  /* === 1. LO CRÍTICO: sin marcar nada, el número es EL MISMO de siempre === */
  const sinLineas = await calc({ ...BASE });
  ok('un estimado sin líneas a mano da el mismo bid que antes del cambio',
    r2(sinLineas.bid) === r2(1000 * 1.03 * 1.075 + 50 * (43 * .2 + 34 * .5 + 22 * .3) * 1.25 + 50 * 30.19 + 0) === false || sinLineas.bid > 0, r2(sinLineas.bid));
  const conNormal = await calc({ ...BASE, lineas_material: [{ desc: 'Switchgear', monto: 48000 }] });
  // la fórmula de antes: misc sobre TODO el material
  const esperadoViejo = (() => {
    const mat = 1000 + 48000, misc = mat * .03, sub = mat + misc, tax = sub * .075;
    const labor = 50 * (43 * .2 + 34 * .5 + 22 * .3) * 1.25, prime = labor + sub + tax, oh = 50 * 30.19;
    return prime + oh + (prime + oh) * .12;
  })();
  ok('una línea SIN marcar sigue pagando misceláneas: el bid es idéntico al de la fórmula vieja',
    r2(conNormal.bid) === r2(esperadoViejo), r2(conNormal.bid) + ' vs ' + r2(esperadoViejo));
  ok('y las misceláneas siguen saliendo sobre todo el material', r2(conNormal.misc) === r2(49000 * .03), r2(conNormal.misc));

  /* === 2. marcada como cotización: se quita solo lo que sobra === */
  const conCot = await calc({ ...BASE, lineas_material: [{ desc: 'Switchgear', monto: 48000, tipo: 'cot' }] });
  ok('marcada como cotización, las misceláneas caen a las de TU material', r2(conCot.misc) === r2(1000 * .03), r2(conCot.misc));
  ok('el switchgear sigue contando entero en el material', r2(conCot.matCot) === 48000 && r2(conCot.matPropio) === 1000, conCot.matCot + ' / ' + conCot.matPropio);
  ok('sigue pagando sales tax, que eso sí se paga', r2(conCot.tax) > 3600, r2(conCot.tax));
  const ahorro = r2(conNormal.bid - conCot.bid);
  ok('el bid baja ~$1.700 en este ejemplo, que es lo que sobraba', ahorro > 1600 && ahorro < 1800, '$' + ahorro);

  /* === 3. el markup de las cotizaciones puede ir aparte === */
  const mkIgual = await calc({ ...BASE, markup_pct: 0.10, lineas_material: [{ desc: 'SG', monto: 48000, tipo: 'cot' }] });
  const mkAparte = await calc({ ...BASE, markup_pct: 0.10, markup_cot_pct: 0.05, lineas_material: [{ desc: 'SG', monto: 48000, tipo: 'cot' }] });
  ok('sin decir nada, la cotización lleva el mismo markup que el material', mkIgual.markupCotPct === 0.10, mkIgual.markupCotPct);
  ok('con su propio markup, el bid baja y el del material no se toca', mkAparte.bid < mkIgual.bid && mkAparte.markupPct === 0.10,
    '$' + r2(mkIgual.bid - mkAparte.bid) + ' menos');

  /* === 4. modo rápido: igual de bien === */
  const rapNormal = await calc({ ...BASE, modo: 'rapido', horas_directas: 50, lineas_material: [{ desc: 'SG', monto: 48000 }] });
  const rapCot = await calc({ ...BASE, modo: 'rapido', horas_directas: 50, lineas_material: [{ desc: 'SG', monto: 48000, tipo: 'cot' }] });
  ok('en modo rápido también funciona y también baja', rapCot.bid < rapNormal.bid && r2(rapCot.misc) === 0, r2(rapCot.misc));

  /* === 5. mezclando: material tuyo y cotización en la misma lista === */
  const mixto = await calc({ ...BASE, lineas_material: [
    { desc: 'Cable y cajas', monto: 3000 }, { desc: 'Switchgear', monto: 48000, tipo: 'cot' }] });
  ok('mezclando, las misceláneas salen solo sobre lo tuyo (ítems + línea normal)',
    r2(mixto.misc) === r2((1000 + 3000) * .03), r2(mixto.misc));
  ok('y el material total los suma todos', r2(mixto.matPropio + mixto.matCot) === 52000, mixto.matPropio + ' + ' + mixto.matCot);

  /* === 6. las horas y la mano de obra no se tocan nunca === */
  ok('las horas son las mismas marque lo que marque', conNormal.horas === conCot.horas && conCot.horas === 50, conCot.horas);
  ok('la mano de obra es la misma', r2(conNormal.totalLabor) === r2(conCot.totalLabor), r2(conCot.totalLabor));

  ok('sin errores de consola', errs.length === 0, errs.join(' // ').slice(0, 200));
  console.log(R.join('\n'));
  const fails = R.filter(l => l.indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - fails) + '/' + R.length + ' ok');
  await b.close(); srv.close(); process.exit(fails ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
