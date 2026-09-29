/* E38 · UNA PIEZA, UN RENGLÓN (29/09). Edgar, con Peninsula: «me pone dos veces
   caja JB 1900… igual que los ground pigtail… los conectores no me los agrupa en
   un solo conteo». La lista de materiales junta la MISMA pieza —mismo item,
   mismo precio, mismas horas— que viene de varias recetas y de lo contado
   suelto, y dice de dónde sale cada parte. Solo la vista: el dinero no se mueve.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e38.js            */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json' };
const srv = http.createServer((req, res) => { let p = req.url.split('?')[0]; if (p === '/') p = '/index.html'; fs.readFile(path.join(ROOT, p), (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d); }); });
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));
// Peninsula en corto: la caja 1900 en dos renglones sueltos (dos partidas) y dentro de la receta del duplex; el pigtail y el conector en tres sitios
const ITEMS = [
  { id: 'a', item: 'JB 1900 BOX', precio: 1.04, horas: 0.25, cantidad: 45, codigo: '09-COND', origen: 'takeoff' },
  { id: 'b', item: 'JB 1900 BOX', precio: 1.04, horas: 0.25, cantidad: 127, codigo: '11-LIGHT', origen: 'takeoff' },
  { item: 'JB  1900  BOX', precio: 1.04, horas: 0.25, cantidad: 98, deEnsamble: 'RECEPTÁCULO 20A DUPLEX — EMT' },
  { id: 'c', item: '#12     GROUND PIGTAIL', precio: 0.17, horas: 0.01, cantidad: 135, codigo: '11-LIGHT', origen: 'takeoff' },
  { item: '#12     GROUND PIGTAIL', precio: 0.17, horas: 0.01, cantidad: 98, deEnsamble: 'RECEPTÁCULO 20A DUPLEX — EMT' },
  { item: '#12     GROUND PIGTAIL', precio: 0.17, horas: 0.01, cantidad: 22, deEnsamble: 'RECEPTÁCULO GFCI 20A — EMT' },
  { item: '1/2"       EMT S.S. D/C CONNECTOR', precio: 1.1679, horas: 0.06, cantidad: 196, deEnsamble: 'RECEPTÁCULO 20A DUPLEX — EMT' },
  { id: 'd', item: '1/2"       EMT S.S. D/C CONNECTOR', precio: 1.1679, horas: 0.06, cantidad: 270, codigo: '11-LIGHT', origen: 'takeoff' },
  // el mismo nombre a OTRO precio (cambiado a mano en este estimado) NO se junta
  { id: 'e', item: '4" RECESSED CAN LIGHT', precio: 0, horas: 0.75, cantidad: 85, codigo: '11-LIGHT', origen: 'takeoff' },
  { item: '4" RECESSED CAN LIGHT', precio: 172, horas: 0.75, cantidad: 3, deEnsamble: 'RECESSED CAN 4" — EMT' },
  { id: 'f', item: 'BREAKER 1P 20A', precio: 8, horas: 0.25, cantidad: 13, codigo: '05-PANEL', origen: 'takeoff' }
];
(async () => {
  await new Promise(r => srv.listen(8931, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const p = await (await b.newContext({ serviceWorkers: 'block' })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.route(/supabase\.co/, r => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }));
  await p.goto('http://localhost:8931/index.html'); await p.waitForFunction(() => window.MXP_PRUEBA && window.MXP_PRUEBA.agrupaMateriales, null, { timeout: 15000 });
  const r = await p.evaluate(items => { const copia = JSON.stringify(items); const g = window.MXP_PRUEBA.agrupaMateriales(items); return { g: JSON.parse(JSON.stringify(g)), intacto: JSON.stringify(items) === copia }; }, ITEMS);
  const G = r.g, de = n => G.find(x => x.i.item.replace(/\s+/g, ' ') === n);
  const jb = de('JB 1900 BOX'), pig = de('#12 GROUND PIGTAIL'), con = de('1/2" EMT S.S. D/C CONNECTOR');
  ok('la caja 1900: UN renglón con 45 + 127 contadas + 98 de la receta = 270', G.filter(x => /1900/.test(x.i.item)).length === 1 && jb.i.cantidad === 270 && jb.filas === 3, jb && jb.i.cantidad);
  ok('… y dice de dónde sale cada parte, con la partida de lo contado', jb.orden.join(' | ') === 'contadas aparte (09-COND) | contadas aparte (11-LIGHT) | de RECEPTÁCULO 20A DUPLEX — EMT' && jb.partes['contadas aparte (09-COND)'] === 45, jb.orden.join(' | '));
  ok('el ground pigtail: UN renglón, 135 + 98 + 22 = 255', G.filter(x => /PIGTAIL/.test(x.i.item)).length === 1 && pig.i.cantidad === 255 && pig.filas === 3, pig && pig.i.cantidad);
  ok('el conector 1/2": UN renglón, 196 + 270 = 466', con && con.i.cantidad === 466 && con.filas === 2, con && con.i.cantidad);
  ok('el mismo nombre a OTRO precio no se junta (la luz a $0 y la de $172 son dos renglones)', G.filter(x => /RECESSED CAN/.test(x.i.item)).length === 2);
  ok('lo que viene de un solo sitio sigue igual (el breaker, con su id para editarlo)', de('BREAKER 1P 20A').filas === 1 && de('BREAKER 1P 20A').conId.length === 1);
  ok('el orden es el de la primera aparición', G.map(x => x.i.item.replace(/\s+/g, ' ')).join(' | ') === 'JB 1900 BOX | #12 GROUND PIGTAIL | 1/2" EMT S.S. D/C CONNECTOR | 4" RECESSED CAN LIGHT | 4" RECESSED CAN LIGHT | BREAKER 1P 20A', G.map(x => x.i.item).join(' | '));
  const dinero = a => a.reduce((s, x) => s + x.cantidad * x.precio, 0), horas = a => a.reduce((s, x) => s + x.cantidad * x.horas, 0);
  const dG = G.reduce((s, x) => s + x.i.cantidad * x.i.precio, 0), hG = G.reduce((s, x) => s + x.i.cantidad * x.i.horas, 0);
  ok('el dinero y las horas no se mueven ni un centavo', Math.abs(dG - dinero(ITEMS)) < 1e-9 && Math.abs(hG - horas(ITEMS)) < 1e-9, dG.toFixed(2) + ' / ' + hG.toFixed(2));
  ok('los renglones originales no se tocan', r.intacto);
  ok('sin errores de página', errs.length === 0, errs.join(' | '));
  console.log('E38 · UNA PIEZA, UN RENGLÓN\n' + R.join('\n'));
  const mal = R.filter(x => x.startsWith('  ✗')).length;
  console.log(mal ? '\n' + mal + ' FALLAN' : '\nTODO BIEN (' + R.length + ')');
  await b.close(); srv.close(); process.exit(mal ? 1 : 0);
})();
