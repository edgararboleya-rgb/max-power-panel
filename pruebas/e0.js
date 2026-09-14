/* E0 · «Quién pone el material».
   La lógica del $0 es pura (ni red ni sesión), así que se prueba dándole un
   catálogo de mentira y preguntándole. Lo que se comprueba es lo que le pasa
   a Edgar de verdad: que un switchgear sin material NO se vea normal, que el
   cliente solo lea lo que Edgar confirmó, y que el precio no se mueva.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e0.js            */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json' };
const srv = http.createServer((req, res) => {
  let p = req.url.split('?')[0]; if (p === '/') p = '/index.html';
  fs.readFile(path.join(ROOT, p), (e, d) => {
    if (e) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d);
  });
});
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));

/* El catálogo de mentira: un ejemplar de cada estado que existe de verdad. */
const CAT = [
  { id: 1, item: '400A SWITCHGEAR', seccion: 'SWITCHGEAR', precio: 0, horas_unidad: 14, cero_motivo: 'suministro', cero_revisado: null },
  { id: 2, item: 'CEILING FAN - INSTALL ONLY', seccion: 'LIGHTING FIXTURES', precio: 0, horas_unidad: 1, cero_motivo: 'by_owner', cero_revisado: '2026-09-14' },
  { id: 3, item: 'WALL SCONCE - INSTALL ONLY', seccion: 'LIGHTING FIXTURES', precio: 0, horas_unidad: 0.5, cero_motivo: 'by_owner', cero_revisado: null },
  { id: 4, item: '5" GRS CONDUIT', seccion: 'RACEWAY', precio: 0, horas_unidad: 0.2, cero_motivo: 'falta_precio', cero_revisado: '2026-09-14' },
  { id: 5, item: 'SERVICE LABOR (HOUR)', seccion: 'SERVICE', precio: 0, horas_unidad: 1, cero_motivo: 'solo_labor', cero_revisado: '2026-09-14' },
  { id: 6, item: 'Parking Fee (downtown)', seccion: 'PROJECT GENERAL', precio: 0, horas_unidad: 0, cero_motivo: 'tarifa', cero_revisado: '2026-09-14' },
  { id: 7, item: 'DEMO - Panels', seccion: 'DEMOLITION', precio: 0, horas_unidad: 1.5, cero_motivo: null, cero_revisado: null },
  { id: 8, item: '20A DUPLEX RECEPTACLE', seccion: 'WIRING DEVICES', precio: 3.4, horas_unidad: 0.3, cero_motivo: null, cero_revisado: null }
];
const L = (item, cantidad, precio, horas) => ({ item, cantidad, precio, horas });

(async () => {
  await new Promise(r => srv.listen(8861, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8861/index.html'); await p.waitForTimeout(500);
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c, config: { cero_aviso: 2 }, ensambleItems: [{ item: '5" GRS CONDUIT' }] }), CAT);
  const cero = (linea, est) => p.evaluate(([l, e]) => window.MXP_PRUEBA.e0.cero(l, e), [linea, est || {}]);

  /* === 1. cada $0 dice POR QUÉ, y solo algunos alertan === */
  const z1 = await cero(L('400A SWITCHGEAR', 2, 0, 14));
  ok('switchgear a $0 → POR COTIZAR, alerta, y con «?» porque lo supuso la regla',
    z1.est === 'suministro' && z1.alerta && /POR COTIZAR \?/.test(z1.chip), JSON.stringify(z1.chip) + ' alerta=' + z1.alerta);
  const z2 = await cero(L('CEILING FAN - INSTALL ONLY', 4, 0, 1));
  ok('el que pone el cliente → BY OWNER confirmado y NO alerta', z2.est === 'by_owner' && z2.conf && !z2.alerta, z2.chip);
  const z3 = await cero(L('5" GRS CONDUIT', 10, 0, 0.2));
  ok('un tubo sin precio → FALTA PRECIO y alerta (eso es un error, no un acuerdo)', z3.est === 'falta_precio' && z3.alerta, z3.chip);
  const z4 = await cero(L('SERVICE LABOR (HOUR)', 8, 0, 1));
  ok('mano de obra pura → SOLO LABOR y se calla', z4.est === 'solo_labor' && !z4.alerta, z4.chip);
  const z5 = await cero(L('Parking Fee (downtown)', 1, 0, 0));
  ok('una tarifa → TARIFA y se calla', z5.est === 'tarifa' && !z5.alerta, z5.chip);
  const z6 = await cero(L('DEMO - Panels', 3, 0, 1.5));
  ok('sin clasificar → pregunta «¿QUIÉN LO PONE?» (NULL falla hacia preguntar)', z6.est === 'revisar' && z6.alerta, z6.chip);
  const z7 = await cero(L('UN NOMBRE QUE NO EXISTE', 1, 0, 0.5));
  ok('un nombre que no está en el catálogo → SIN CATÁLOGO y alerta', z7.est === 'huerfano' && z7.alerta, z7.chip);
  const z8 = await cero(L('20A DUPLEX RECEPTACLE', 20, 3.4, 0.3));
  ok('un renglón con precio se queda como siempre: sin chip y sin ruido', z8.est === 'normal' && !z8.chip && !z8.alerta, JSON.stringify(z8.chip));

  /* === 2. la cotización del supply apaga la sección entera === */
  const zc = await cero(L('400A SWITCHGEAR', 2, 0, 14), { cero_notas: { 'S:SWITCHGEAR': { d: 'cotizado' } } });
  ok('al decir «ya lo cotizé», la sección entera pasa a COTIZADO y deja de alertar',
    zc.est === 'cotizado' && !zc.alerta, zc.chip);
  const zo = await cero(L('5" GRS CONDUIT', 1, 0, 0.2), { cero_notas: { 'S:SWITCHGEAR': { d: 'cotizado' } } });
  ok('y no apaga otras secciones', zo.est === 'falta_precio' && zo.alerta, zo.chip);

  /* === 3. al cliente SOLO llega lo que Edgar confirmó === */
  const items = [L('400A SWITCHGEAR', 2, 0, 14), L('CEILING FAN - INSTALL ONLY', 4, 0, 1),
                 L('WALL SCONCE - INSTALL ONLY', 2, 0, 0.5), L('5" GRS CONDUIT', 10, 0, 0.2),
                 L('DEMO - Panels', 3, 0, 1.5), L('20A DUPLEX RECEPTACLE', 20, 3.4, 0.3)];
  const ex = await p.evaluate(i => window.MXP_PRUEBA.e0.excluye({}, i), items);
  ok('una sola línea de exclusión: la luminaria confirmada (no 78 líneas)',
    ex.length === 2 && /Lighting fixtures/.test(ex[0]) && /\(4\)/.test(ex[0]), JSON.stringify(ex[0] || '').slice(0, 110));
  ok('el switchgear POR COTIZAR no se excluye nunca: ese material lo paga Edgar',
    !ex.join(' ').match(/Switchgear/i), ex.length + ' líneas');
  ok('el by_owner SIN confirmar tampoco sale (lo supuso la app, no Edgar)',
    !ex.join(' ').match(/sconce/i));
  ok('lo que no se sabe (falta precio, sin clasificar) jamás va al contrato',
    !ex.join(' ').match(/GRS|DEMO/i));
  ok('cierra con la cláusula de garantía y retrasos', /not warranted by Max Power/.test(ex[ex.length - 1] || ''));

  /* === 4. la propuesta cambia solo si hay exclusiones === */
  const cFake = { bid: 10000, items, autos: [], horas: 100 };
  const t1 = await p.evaluate(c => window.MXP_PRUEBA.e0.propuesta({ id: 1, nombre: 'X', escenario: 'B' }, c), cFake);
  ok('con exclusiones, la propuesta ya NO promete todos los materiales',
    !/Incluye mano de obra, materiales,/.test(t1) && /EXCEPTO/.test(t1) && /NOT INCLUDED/.test(t1));
  const t2 = await p.evaluate(() => window.MXP_PRUEBA.e0.propuesta({ id: 1, nombre: 'X', escenario: 'B' },
    { bid: 10000, items: [{ item: '20A DUPLEX RECEPTACLE', cantidad: 20, precio: 3.4, horas: 0.3 }], autos: [], horas: 6 }));
  ok('sin exclusiones, la propuesta sale letra por letra como siempre',
    /Incluye mano de obra, materiales, misceláneas y supervisión según el alcance\./.test(t2) && !/NOT INCLUDED/.test(t2));

  /* === 5. el aviso antes de mandar el bid === */
  const av = await p.evaluate(c => window.MXP_PRUEBA.e0.salida({ id: 1 }, c), cFake);
  ok('el aviso agrupa por sección y cuenta las horas que SÍ están en el precio',
    /SWITCHGEAR — 1 renglón, 28 h/.test(av) && /sin material/.test(av), (av.split('\n')[0] || '').slice(0, 80));
  ok('el aviso avisa de los by owner que la app supuso', /supuso la app/.test(av));
  ok('Aceptar = seguir, Cancelar = volver (no se invierte la inercia)',
    /Aceptar = seguir así/.test(av) && /Cancelar = volver/.test(av));
  const av0 = await p.evaluate(() => window.MXP_PRUEBA.e0.salida({ id: 1 },
    { bid: 1, items: [{ item: '20A DUPLEX RECEPTACLE', cantidad: 1, precio: 3.4, horas: 0.3 }], autos: [] }));
  ok('sin renglones a $0 no hay aviso ninguno', av0 === '', JSON.stringify(av0));

  /* === 6. el interruptor devuelve la app de ayer === */
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c, config: { cero_aviso: 1 } }), CAT);
  const avOff = await p.evaluate(c => window.MXP_PRUEBA.e0.salida({ id: 1 }, c), cFake);
  ok('con cero_aviso = 1 quedan los chips pero desaparece el aviso de salida', avOff === '', JSON.stringify(avOff));

  /* === 7. nada de esto toca el dinero === */
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c, config: { cero_aviso: 2 } }), CAT);
  const suma = await p.evaluate(i => i.reduce((s, x) => s + x.cantidad * x.precio, 0), items);
  ok('el material del estimado sigue siendo el mismo número que antes de E0', suma === 68, suma);

  /* === 8. los estimados de MXP MEP: identificados y en modo lectura === */
  ok('un estimado sin empresa es tuyo', (await p.evaluate(() => window.MXP_PRUEBA.e0.esMep({ id: 1 }))) === false);
  ok('uno marcado mep se reconoce', (await p.evaluate(() => window.MXP_PRUEBA.e0.esMep({ id: 1, empresa: 'mep' }))) === true);
  const rMep = await p.evaluate(c => window.MXP_PRUEBA.e0.mep({ id: 9, nombre: 'Epic — sala eléctrica', cliente: 'Obra 4', escenario: 'B', empresa: 'mep', sqft: 2000 }, c),
    { bid: 48000, items, autos: [], horas: 320, totalLabor: 28000, totalMaterial: 12000, misc: 900, overhead: 5000, profit: 2100, tarifaCargada: 150 });
  ok('el resumen de MXP MEP NO lleva el membrete ni la licencia de Max Power',
    !/MAX POWER ELECTRICAL SOLUTIONS/.test(rMep) && !/EC13016045/.test(rMep), rMep.split('\n')[0]);
  ok('pero sí lleva el número, las horas y el $/sq ft', /TOTAL: \$48,000\.00/.test(rMep) && /320 h/.test(rMep) && /\/sq ft/.test(rMep));
  ok('y dice claramente que no es una propuesta ni un contrato', /No es una propuesta ni un contrato/.test(rMep));
  ok('arrastra las exclusiones igual que un estimado tuyo', /NO INCLUYE/.test(rMep));

  ok('sin errores de consola', errs.length === 0, errs.join(' // ').slice(0, 200));
  console.log(R.join('\n'));
  const fails = R.filter(l => l.indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - fails) + '/' + R.length + ' ok');
  await b.close(); srv.close(); process.exit(fails ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
