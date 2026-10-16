/* E41 · LA COTIZACIÓN DEL SUPPLY SE VE EN EL RESUMEN (06/10). Edgar, con
   Mariners: «¿dónde está ese material? ¿en qué parte del resumen? necesito
   saber si se está cobrando o no». La cuota de CED iba sumada DENTRO de
   «Material (ítems)» sin nombre. Ahora el resumen separa lo contado, lo a
   mano y cada cotización; y «toda esta sección está en el precio» cubre
   también el renglón con precio de catálogo que va a $0 por estar en la cuota.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e41.js          */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json' };
const srv = http.createServer((req, res) => { let p = req.url.split('?')[0]; if (p === '/') p = '/index.html'; fs.readFile(path.join(ROOT, p), (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d); }); });
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));
const CAT = [
  { id: 1, item: '3-1/2"     EMT CONDUIT', seccion: 'RACEWAY', unidad: 'LF', precio: 8.5, horas_unidad: 0.08, codigo: '09-COND' },
  { id: 2, item: '600A/3P DISCONNECT SWITCH', seccion: 'SWITCHGEAR', unidad: 'E', precio: 0, horas_unidad: 10, codigo: '05-PANEL', cero_motivo: 'suministro' },
  { id: 3, item: 'SURGE PROTECTIVE DEVICE (Type 1)', seccion: 'LIGHTNING PROTECTION & GROUNDING', unidad: 'EA', precio: 385, horas_unidad: 1.5, codigo: '07-GND' },
  { id: 4, item: '# 350 MCM LUGS', seccion: 'WIRING', unidad: 'E', precio: 17.33, horas_unidad: 0.25, codigo: '08-ROUGH' }
];
const ESC = [{ id: 'MEP', foreman: 45, journeyman: 35, helper: 20, pct_foreman: .15, pct_journeyman: .4, pct_helper: .35, benefits: .25, tax_material: .075, overhead_hh: 0, overhead_pct: 0.15, profit: .10 }];
const ITEMS = [
  { id: 1, estimado_id: 47, item: '3-1/2"     EMT CONDUIT', cantidad: 340, precio: 9.21, horas: 0.08, unidad: 'LF', codigo: '06-FEED', orden: 1 },
  { id: 2, estimado_id: 47, item: '600A/3P DISCONNECT SWITCH', cantidad: 2, precio: 0, horas: 10, unidad: 'E', codigo: '05-PANEL', orden: 2 },
  { id: 3, estimado_id: 47, item: 'SURGE PROTECTIVE DEVICE (Type 1)', cantidad: 1, precio: 0, horas: 1.5, unidad: 'EA', codigo: '05-PANEL', orden: 3 },
  { id: 4, estimado_id: 47, item: '# 350 MCM LUGS', cantidad: 40, precio: 0, horas: 0.25, unidad: 'E', codigo: '06-FEED', orden: 4 }
];
const EST = { id: 47, nombre: 'Mariners Hospital Chillers Replacement', empresa: 'mep', escenario: 'MEP', modo: 'planos', estado: 'borrador', factor: 1, tax_pct: 0.075,
  lineas_material: [{ desc: 'CED Q1009435 rev 6→7 (Mike Jarot) — GEAR: 2 switches 600A…', monto: 38143.01, tipo: 'cot' }, { desc: 'Hilti firestop', monto: 600, tipo: 'allow' }, { desc: 'Tubo a mano', monto: 250 }] };
const cerca = (a, b) => Math.abs(a - b) < 0.011;
(async () => {
  await new Promise(r => srv.listen(8942, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const p = await (await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.route(/supabase\.co/, r => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }));
  await p.goto('http://localhost:8942/index.html'); await p.waitForFunction(() => window.MXP_PRUEBA && window.MXP_PRUEBA.e0, null, { timeout: 15000 });
  await p.evaluate(([c, e, it, est]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: { misc_pct: 0.03, merma_cable: 0.1, merma_tuberia: 0.05 }, items: it, estimados: [est], ensambles: [], estEnsambles: [] }), [CAT, ESC, ITEMS, EST]);

  /* === 1. los números no se mueven: solo cambia cómo se ven === */
  const c = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), EST);
  const contado = 340 * 9.21;
  ok('el material contado son los renglones + automáticos ($3,131.40 de tubo; el gear a $0 no suma)', cerca(c.items.reduce((s, i) => s + i.cantidad * i.precio, 0), contado), c.items.reduce((s, i) => s + i.cantidad * i.precio, 0));
  ok('la cotización del supply entra como matCot ($38,143.01) y el allowance como costo directo ($600)', cerca(c.matCot, 38143.01) && cerca(c.costos, 600), JSON.stringify([c.matCot, c.costos]));

  /* === 2. el resumen las enseña en filas propias === */
  const ed = await p.evaluate(() => { try { return window.MXP_PRUEBA.e0.editor(47); } catch (err) { return { err: String(err) }; } });
  const t = ed.txt || '';
  ok('el editor se pinta', !ed.err && t.length > 100, ed.err || '');
  // innerText pega las dos celdas sin espacio: «Material contado (ítems)$3,131.40»
  const res = t.slice(t.indexOf('Resumen — fórmula'));
  ok('fila «Material contado (ítems)» con lo contado, SIN la cotización', /Material contado \(ítems[^)]*\)\s*\$3,131\.40/.test(res), (res.match(/Material contado.*$/m) || [''])[0]);
  ok('fila «+ Material a mano (1 línea)» con los $250', /\+ Material a mano \(1 línea\)\s*\$250\.00/.test(res), (res.match(/\+ Material a mano.*$/m) || [''])[0]);
  ok('fila «+ Cotización del supply: CED Q1009435 rev 6→7» con sus $38,143.01', /\+ Cotización del supply: CED Q1009435 rev 6→7[^\n]*\$38,143\.01/.test(t), (t.match(/Cotización del supply.*$/m) || [''])[0]);
  ok('el allowance NO está en Materiales: va en Otros gastos como logística/allowance', !/Hilti[^\n]*\n[^\n]*Total de materiales/.test(t) && /Logística, allowances y subcontratos[^\n]*\$600\.00/.test(t));
  const idx = (re) => res.search(re);
  ok('orden: contado → a mano → cotización → merma → misceláneas → tax → total', idx(/Material contado/) < idx(/\+ Material a mano/) && idx(/\+ Material a mano/) < idx(/Cotización del supply/) && idx(/Cotización del supply/) < idx(/\+ Merma/) && idx(/\+ Merma/) < idx(/\+ Misceláneas/) && idx(/\+ Misceláneas/) < idx(/= Total de materiales/));

  /* === 3. los renglones a $0 que están en la cuota dicen «Cotizado» === */
  const chips = await p.evaluate(est => ['600A/3P DISCONNECT SWITCH', 'SURGE PROTECTIVE DEVICE (Type 1)', '# 350 MCM LUGS'].map(n => window.MXP_PRUEBA.e0.cero({ item: n, precio: 0, cantidad: 1 }, est).est), EST);
  ok('sin la marca de sección: el switch dice «por cotizar» y el SPD (con precio en el catálogo) «¿quién lo pone?»', chips.join(',') === 'suministro,revisar,revisar', chips.join(','));
  const EST2 = { ...EST, cero_notas: { 'S:SWITCHGEAR': { d: 'cotizado' }, 'S:LIGHTNING PROTECTION & GROUNDING': { d: 'cotizado' }, 'S:WIRING': { d: 'cotizado' } } };
  const chips2 = await p.evaluate(est => ['600A/3P DISCONNECT SWITCH', 'SURGE PROTECTIVE DEVICE (Type 1)', '# 350 MCM LUGS'].map(n => { const z = window.MXP_PRUEBA.e0.cero({ item: n, precio: 0, cantidad: 1 }, est); return z.est + (z.alerta ? '!' : ''); }), EST2);
  ok('con «toda esta sección está en el precio»: los tres dicen Cotizado y no alertan (también el SPD y los lugs, que tienen precio en el catálogo)', chips2.join(',') === 'cotizado,cotizado,cotizado', chips2.join(','));
  const noToca = await p.evaluate(est => window.MXP_PRUEBA.e0.cero({ item: '3-1/2"     EMT CONDUIT', precio: 0, cantidad: 1 }, est).est, { ...EST, cero_notas: { 'S:SWITCHGEAR': { d: 'cotizado' } } });
  ok('la marca de SWITCHGEAR no toca un tubo (RACEWAY) a $0: sigue preguntando', noToca === 'revisar', noToca);

  /* === 4. el papel interno de MEP lo dice === */
  const mep = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.mep(e, c), [EST, c]);
  ok('el resumen MEP dice «de ello, cotizaciones del supply: $38,143.01»', /de ello, cotizaciones del supply: \$38,143\.01/.test(mep), (mep.match(/de ello.*$/m) || [''])[0]);

  ok('sin errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('E41 · LA COTIZACIÓN SE VE EN EL RESUMEN\n' + R.join('\n'));
  const mal = R.filter(x => x.startsWith('  ✗')).length;
  console.log(mal ? '\n' + mal + ' FALLAN' : '\nTODO BIEN (' + R.length + ')');
  await b.close(); srv.close(); process.exit(mal ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
