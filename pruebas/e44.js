/* E44 · Supervisión por TIEMPO en Otros gastos (06/10).
   Horas a la semana × semanas de obra × $/h con cargas. No es un % del labor.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e44.js          */
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
const r2 = v => Math.round(v * 100) / 100;
const CAT = [{ id: 1, item: 'CAJA', seccion: 'RACEWAY', precio: 10, horas_unidad: 5 }];
const ESC = [{ id: 'MEP', nombre: 'MXP MEP', foreman: 45, journeyman: 35, helper: 20,
  mezcla: [{ rol: 'Foreman', tarifa: 45, pct: .2, tipo: 'prod' }, { rol: 'Journeyman', tarifa: 35, pct: .4, tipo: 'prod' }, { rol: 'Helper', tarifa: 20, pct: .4, tipo: 'prod' }],
  benefits: .25, tax_material: .065, overhead_hh: 30.19, overhead_pct: .15, profit: .15 }];
const CFG = { misc_pct: 0.03 };
const ITEMS = [{ id: 1, estimado_id: 7, item: 'CAJA', cantidad: 100, precio: 10, horas: 5, unidad: 'EA', orden: 1 }];
const BASE = { id: 7, nombre: 'Prueba', escenario: 'MEP', empresa: 'mep', modo: 'servicio', estado: 'borrador', factor: 1 };
const SUP = { sup_hsem: 10, sup_sem: 6, sup_hora: 75 };

(async () => {
  await new Promise(r => srv.listen(8894, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8894/index.html'); await p.waitForTimeout(500);
  await p.evaluate(([c, e, cf, it]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] });
  }, [CAT, ESC, CFG, ITEMS]);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);
  const gen = (est, cfg) => p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.generales(e, c), [est, cfg || {}]);
  const sup = g => g.renglones.find(r => r.id === 'pm');

  /* 1. la cuadrilla de 5 con las tarifas de siempre: el foreman sale de las mismas horas */
  const c0 = await calc(BASE);
  ok('tarifa mezclada $31.00 (foreman 20 % $45 · journeymen 40 % $35 · helpers 40 % $20)', r2(c0.tarifaMezclada) === 31, c0.tarifaMezclada);
  ok('500 h × $31 = $15,500 de labor base, más 25 % de beneficios = $19,375', r2(c0.laborBase) === 15500 && r2(c0.totalLabor) === 19375, c0.totalLabor);
  ok('sin supervisión puesta, Otros gastos vale 0', r2(c0.generales) === 0);

  /* 2. la supervisión por tiempo */
  const g = await gen({ ...BASE, gastos_generales: SUP });
  ok('el renglón existe y es de tiempo (sup)', sup(g) && sup(g).sup === true);
  ok('10 h/sem × 6 sem = 60 h × $75 = $4,500', sup(g).horas === 60 && sup(g).hora === 75 && sup(g).total === 4500, JSON.stringify(sup(g)));
  ok('sigue habiendo 10 renglones, el lift primero', g.renglones.length === 10 && g.renglones[0].id === 'lift');
  const porDefecto = await gen({ ...BASE, gastos_generales: { sup_hsem: 8, sup_sem: 2 } });
  ok('sin $/h propio usa $75 (superintendent $60 + 25 % de cargas)', sup(porDefecto).hora === 75 && sup(porDefecto).total === 1200);
  const casa = await gen({ ...BASE, gastos_generales: { sup_hsem: 8, sup_sem: 2 } }, { sup_hora: 90 });
  ok('y la casa puede tener el suyo (config sup_hora)', sup(casa).hora === 90 && sup(casa).total === 1440);
  const viejo = await gen({ ...BASE, gastos_generales: { pm: 1730 } });
  ok('lo guardado antes como «pm» en dinero se sigue leyendo, igual: $1,730', sup(viejo).total === 1730 && sup(viejo).horas === 0);
  const mixto = await gen({ ...BASE, gastos_generales: { ...SUP, pm: 500 } });
  ok('y si hay las dos cosas, se suman: $4,500 + $500', sup(mixto).total === 5000);

  /* 3. entra al costo directo, sin tocar las horas ni la hora cargada */
  const c1 = await calc({ ...BASE, gastos_generales: SUP });
  ok('mano de obra no cambia: la supervisión no son horas de instalación', r2(c1.horas) === 500 && r2(c1.totalLabor) === 19375);
  ok('Otros gastos = $4,500 y entra al costo directo', r2(c1.generales) === 4500 && r2(c1.prime - c0.prime) === 4500);
  ok('lleva overhead y profit: el precio sube $4,500 × 1.15 × 1.15', r2(c1.bid - c0.bid) === r2(4500 * 1.15 * 1.15), r2(c1.bid - c0.bid));
  ok('la hora cargada no se infla con ella', Math.abs(c1.tarifaCargada - c0.tarifaCargada) < 0.01, c0.tarifaCargada.toFixed(2) + ' / ' + c1.tarifaCargada.toFixed(2));

  /* 4. se ve: tarjeta, resumen MEP, takeoff */
  const card = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, window.MXP_PRUEBA.e0.calcula(e)), { ...BASE, gastos_generales: SUP });
  ok('la tarjeta pide horas/semana, semanas y $/h, y dice las horas que salen', (card.match(/class="gen-sup"/g) || []).length === 3 && /<b>60 h<\/b>/.test(card) && /Supervisión \/ superintendent/.test(card));
  ok('sin «pm» viejo no aparece la casilla del monto a mano', !/data-id="pm"/.test(card));
  const cardViejo = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, window.MXP_PRUEBA.e0.calcula(e)), { ...BASE, gastos_generales: { pm: 1730 } });
  ok('con «pm» viejo sí, para poder quitarlo', /class="gen-monto" data-id="pm"[^>]*value="1730"/.test(cardViejo));
  const lect = await p.evaluate(e => window.MXP_PRUEBA.e0.generalesCard(e, null, true), { ...BASE, estado: 'congelado', gastos_generales: SUP });
  ok('congelado: se lee «10 h/sem × 6 sem. = 60 h × $75.00»', /10 h\/sem × 6 sem\. = 60 h × \$75\.00/.test(lect) && !/gen-sup/.test(lect));
  const mep = await p.evaluate(e => { const c = window.MXP_PRUEBA.e0.calcula(e); return window.MXP_PRUEBA.e0.mep(e, c); }, { ...BASE, gastos_generales: SUP });
  ok('el resumen MEP lo dice con su cuenta', /Supervisión \/ superintendent \(10 h\/sem × 6 sem = 60 h × \$75\.00\): \$4,500\.00/.test(mep), (mep.match(/Supervisi.*$/m) || [''])[0]);
  const tk = await p.evaluate(e => { const c = window.MXP_PRUEBA.e0.calcula(e); return window.MXP_PRUEBA.e0.takeoff(e, c); }, { ...BASE, gastos_generales: SUP });
  ok('el takeoff lo lleva como 60 HR × $75 en el bloque de otros gastos', /Supervisión \/ superintendent\totros gastos · 10\.00 h\/sem × 6\.00 sem\t60\.00\tHR\t75\.00\t0\t4500\.00/.test(tk), (tk.match(/Supervisi.*$/m) || [''])[0]);
  ok('sin errores de página', errs.length === 0, errs.join(' | '));

  await b.close(); srv.close();
  console.log('E44 · supervisión por tiempo'); console.log(R.join('\n'));
  const mal = R.filter(l => l.startsWith('  ✗')).length;
  console.log(mal ? `FALLA (${mal})` : `TODO BIEN (${R.length})`);
  process.exit(mal ? 1 : 0);
})();
