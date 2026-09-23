/* E36 · Tanda 2 de Mariners (23/09): la merma automática solo en modo planos,
   un estimado de MXP MEP se congela y guarda su resultado, y el papel para el
   cliente de MXP MEP va en lump sum, en inglés, sin overhead, profit, horas ni
   el membrete de Max Power.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e36.js          */

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
  await new Promise(r => srv.listen(8867, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8867/index.html'); await p.waitForTimeout(500);
  const CAT2 = CAT.concat([{ id: 9, item: '3/4" EMT CONDUIT', seccion: 'RACEWAY', precio: 1, horas_unidad: 0.04, unidad: 'LF' },
                           { id: 10, item: 'PERMISO E INSPECCIONES (por proyecto)', seccion: 'LABOR', precio: 0, horas_unidad: 6 }]);
  const ITEMS = [{ id: 1, estimado_id: 7, item: 'CAJA', cantidad: 100, precio: 10, horas: 0.5, unidad: 'EA', orden: 1 },
                 { id: 2, estimado_id: 7, item: '3/4" EMT CONDUIT', cantidad: 1000, precio: 1, horas: 0.04, unidad: 'LF', orden: 2 },
                 { id: 3, estimado_id: 7, item: 'PERMISO E INSPECCIONES (por proyecto)', cantidad: 1, precio: 0, horas: 6, unidad: 'E', orden: 3 }];
  await p.evaluate(([c, e, cf, it]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] }), [CAT2, ESC, CFG, ITEMS]);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);
  const BASE = { id: 7, nombre: 'Mariners Hospital Chillers Replacement', cliente: 'Baptist Health (via GC)', escenario: 'B', estado: 'borrador', factor: 1 };

  /* === 1. merma: solo en planos === */
  const pl = await calc({ ...BASE, modo: 'planos' });
  const re = await calc({ ...BASE, modo: 'remodelacion' });
  const se = await calc({ ...BASE, modo: 'servicio' });
  ok('en modo planos la merma de tubería sigue: 1.000 ft × $1 × 5 %', cerca(pl.mermaMat, 50), r2(pl.mermaMat));
  ok('en remodelación ya no hay merma automática', re.mermaMat === 0 && re.mermaHoras === 0, re.mermaMat);
  ok('ni en servicio', se.mermaMat === 0, se.mermaMat);
  const congelado = await p.evaluate(e => window.MXP_PRUEBA.e11.foto(e), { ...BASE, modo: 'remodelacion', estado: 'congelado', bid_final: 12345.67, horas_final: 80, material_final: 2000 });
  ok('un congelado de remodelación no se mueve: manda su foto', congelado.bid === 12345.67 && congelado.recalculado === false, congelado.bid);

  /* === 2. la propuesta de MXP MEP para el cliente === */
  const EST = { ...BASE, modo: 'planos', empresa: 'mep', escenario: 'B', valida_dias: 10,
    lineas_material: [{ desc: 'Fire alarm vendor', monto: 9500, tipo: 'allow' }, { desc: 'Hotel y per diem', monto: 5531, tipo: 'log' }] };
  const c = await calc(EST);
  const t = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propMep(e, c), [EST, c]);
  ok('por ahora sale a nombre de MAX POWER, con su licencia (MXP MEP es solo nuestra etiqueta)', /^MAX POWER ELECTRICAL SOLUTIONS, INC\.\nFL EC License #EC13016045/.test(t) && /ELECTRICAL PROPOSAL — /.test(t) && !/MXP MEP/.test(t) && /To: Baptist Health/.test(t));
  ok('en lump sum', t.includes('LUMP SUM PRICE: ' + c.bid.toLocaleString('en-US', { style: 'currency', currency: 'USD' })), (t.match(/LUMP SUM.*$/m) || [''])[0]);
  ok('NO lleva overhead, profit, hora cargada ni horas', !/overhead|profit|hora cargada|\/h\b|\bhoras?\b|\bhours?\b/i.test(t));
  ok('el allowance sale con su monto; la logística no', /Fire alarm vendor: \$9,500\.00/.test(t) && !/Hotel/.test(t));
  ok('la validez es la del estimado y avisa del cobre', /valid for 10 days/.test(t) && /Copper/.test(t));
  ok('el alcance nombra lo que se instala y deja fuera las horas de permiso', /RACEWAY: .*EMT CONDUIT/.test(t) && !/PERMISO/.test(t));
  const otro = await p.evaluate(([e, c]) => { window.MXP_PRUEBA.e0.datos(Object.assign({}, { catalogo: [], escenarios: [], items: [], estimados: [], ensambles: [], estEnsambles: [] }, { config: { emisor_mep: 'INTEGRATED SYSTEMS' } })); return window.MXP_PRUEBA.e0.propMep(e, c); }, [EST, c]);
  ok('el día que Integrated Systems sea oficial, se cambia sin tocar código y sale sin nada de Max Power', /^INTEGRATED SYSTEMS\nELECTRICAL PROPOSAL/.test(otro) && !/Max Power|MAX POWER|EC13016045|mxpes/i.test(otro));
  await p.evaluate(([c, e, cf, it]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] }), [CAT2, ESC, CFG, ITEMS]);
  const interno = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.mep(e, c), [EST, c]);
  ok('el resumen INTERNO sigue teniendo el margen (es para Edgar y Roger)', /Overhead/.test(interno) && /Profit/.test(interno));

  /* === 3. un estimado de MXP MEP guarda su resultado === */
  const res = await p.evaluate(e => window.MXP_PRUEBA.e0.resultado(e), EST);
  ok('el bloque de resultado sale también para MXP MEP', /est-res/.test(res));
  const bm = await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e, { empresa: 'mxp' }), [
    { ...EST, id: 1, resultado: 'ganado', bid_final: 300000 }, { ...BASE, id: 2, modo: 'planos', resultado: 'ganado', bid_final: 5000 }]);
  ok('y el historial de Max Power sigue sin mezclarlo', bm.total === 1, 'total=' + bm.total);

  ok('sin errores de consola', errs.length === 0, errs.join(' // ').slice(0, 200));
  console.log(R.join('\n'));
  const fails = R.filter(l => l.indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - fails) + '/' + R.length + ' ok');
  await b.close(); srv.close(); process.exit(fails ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
