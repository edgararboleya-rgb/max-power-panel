/* E43 · Mano de obra por composición de cuadrilla (06/10).
   Los roles productivos se reparten las horas del estimado; la supervisión
   va encima como % adicional. Las horas por tarea no se tocan.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e43.js          */
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
const VIEJA = [{ rol: 'Superintendent', tarifa: 60, pct: .10 }, { rol: 'Foreman', tarifa: 45, pct: .15 },
               { rol: 'Journeyman', tarifa: 35, pct: .40 }, { rol: 'Helper', tarifa: 20, pct: .35 }];
const NUEVA = [{ rol: 'Electrician', tarifa: 45, pct: .60, tipo: 'prod' }, { rol: 'Helper', tarifa: 28, pct: .40, tipo: 'prod' },
               { rol: 'Foreman', tarifa: 55, pct: .30, tipo: 'sup' }, { rol: 'Superintendent', tarifa: 65, pct: .15, tipo: 'sup' }];
const escMEP = mezcla => ({ id: 'MEP', nombre: 'MXP MEP', foreman: 45, journeyman: 35, helper: 20, mezcla,
  benefits: 0, tax_material: .065, overhead_hh: 30.19, overhead_pct: .15, profit: .10 });
const ESC_B = { id: 'B', foreman: 45, journeyman: 35, helper: 20, pct_foreman: .2, pct_journeyman: .5, pct_helper: .3,
  benefits: .25, tax_material: .075, overhead_hh: 30.19, profit: .12 };
const CFG = { misc_pct: 0.03 };
// 100 cajas × 5 h = 500 h, como Mariners redondeado
const ITEMS = [{ id: 1, estimado_id: 7, item: 'CAJA', cantidad: 100, precio: 10, horas: 5, unidad: 'EA', orden: 1 }];
const BASE = { id: 7, nombre: 'Prueba', escenario: 'MEP', empresa: 'mep', modo: 'servicio', estado: 'borrador', factor: 1 };

(async () => {
  await new Promise(r => srv.listen(8893, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8893/index.html'); await p.waitForTimeout(500);
  const prep = escs => p.evaluate(([c, e, cf, it]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] });
  }, [CAT, escs, CFG, ITEMS]);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);

  /* 1. la cuadrilla de siempre (todo productivo) no se mueve ni un centavo */
  await prep([ESC_B, escMEP(VIEJA)]);
  const v = await calc(BASE);
  ok('la cuadrilla vieja sin tipo sigue dando la misma tarifa mezclada', r2(v.tarifaMezclada) === 33.75, v.tarifaMezclada);
  ok('y el mismo labor: 500 h × $33.75', r2(v.laborBase) === 16875, v.laborBase);
  ok('todos sus roles quedan como productivos', v.lab.filas.every(f => f.tipo === 'prod') && r2(v.lab.horasSup) === 0);
  const vb = await calc({ ...BASE, escenario: 'B', empresa: '' });
  ok('los escenarios tuyos (A/B/C) tampoco se mueven', r2(vb.tarifaMezclada) === r2(45 * .2 + 35 * .5 + 20 * .3), vb.tarifaMezclada);

  /* 2. la cuadrilla de Edgar para MEP: productivos 100 %, supervisión encima */
  await prep([ESC_B, escMEP(NUEVA)]);
  const c = await calc(BASE);
  ok('las horas del estimado no cambian: siguen siendo 500 h por tarea', r2(c.horas) === 500, c.horas);
  const porRol = Object.fromEntries(c.lab.filas.map(f => [f.rol, f]));
  ok('Electricians 300 h × $45 = $13,500', r2(porRol.Electrician.horas) === 300 && r2(porRol.Electrician.total) === 13500);
  ok('Helpers 200 h × $28 = $5,600', r2(porRol.Helper.horas) === 200 && r2(porRol.Helper.total) === 5600);
  ok('Foreman +30 % = 150 h × $55 = $8,250', r2(porRol.Foreman.horas) === 150 && r2(porRol.Foreman.total) === 8250);
  ok('Superintendent +15 % = 75 h × $65 = $4,875', r2(porRol.Superintendent.horas) === 75 && r2(porRol.Superintendent.total) === 4875);
  ok('mano de obra = $32,225', r2(c.laborBase) === 32225, c.laborBase);
  ok('horas con supervisión = 725 (500 + 150 + 75), solo informativas', r2(c.lab.horasTotal) === 725 && r2(c.lab.horasSup) === 225);
  ok('tarifa mezclada resultante = $64.45 por hora productiva', r2(c.tarifaMezclada) === 64.45, c.tarifaMezclada);
  ok('con beneficios en 0 (el $/h ya es con cargas), el total de labor es el mismo', r2(c.totalLabor) === 32225, c.totalLabor);
  ok('overhead y profit siguen igual: 15 % del costo directo y 10 % encima',
    r2(c.overhead) === r2(c.prime * .15) && r2(c.profit) === r2((c.prime + c.overhead) * .10));
  ok('la hora cargada sigue dividiendo entre las horas productivas', r2(c.tarifaCargada) === r2(c.bid / 500), c.tarifaCargada);

  /* 3. se puede sobreescribir en UN estimado sin tocar el escenario */
  const propia = await calc({ ...BASE, mezcla: [{ rol: 'Sub Miami', tarifa: 95, pct: 1, tipo: 'prod' }, { rol: 'Edgar', tarifa: 0, pct: .15, tipo: 'sup' }] });
  ok('un estimado con su propia cuadrilla: sub a $95 todo-incluido y Edgar en $0', r2(propia.laborBase) === 47500, propia.laborBase);
  const otra = await calc(BASE);
  ok('y el escenario no se tocó', r2(otra.laborBase) === 32225);

  /* 4. la suma de % solo mira a los productivos */
  const lab = await p.evaluate(m => window.MXP_PRUEBA.e0.laborPorRol(100, m), NUEVA);
  ok('pctProd suma 1 aunque la supervisión sume 45 % más', r2(lab.pctProd) === 1 && r2(lab.horasSup) === 45);

  /* 5. en pantalla: la tabla por rol en la Cuadrilla y en el resumen */
  await p.evaluate(([c, e, cf, it, est]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [est], ensambles: [], estEnsambles: [] });
  }, [CAT, [ESC_B, escMEP(NUEVA)], CFG, ITEMS, BASE]);
  await p.evaluate(() => window.MXP_PRUEBA.e0.abre ? window.MXP_PRUEBA.e0.abre(7) : null).catch(() => {});
  const txt = await p.evaluate(e => window.MXP_PRUEBA.e0.mep(e, window.MXP_PRUEBA.e0.calcula(e)), BASE);
  ok('el texto del resumen MEP lista los roles con horas, $/h y total', /Electrician: 300 h × \$45(\.00)? = \$13,500/.test(txt), txt.split('\n').find(l => /Electrician/.test(l)));
  ok('y la supervisión con su +', /\+ Foreman: 150 h/.test(txt));
  ok('sin errores de página', errs.length === 0, errs.join(' | '));

  await b.close(); srv.close();
  console.log('E43 · cuadrilla por composición'); console.log(R.join('\n'));
  const mal = R.filter(l => l.startsWith('  ✗')).length;
  console.log(mal ? `FALLA (${mal})` : `TODO BIEN (${R.length})`);
  process.exit(mal ? 1 : 0);
})();
