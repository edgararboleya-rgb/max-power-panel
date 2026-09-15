/* E11 · Historial y benchmarks — ganado, perdido y cuánto por pie.
   Lo que de verdad hay que demostrar: que un benchmark viejo NO se recalcula
   con los precios de hoy (esa es la trampa que hace inútil un historial), que
   nunca se da una media sin decir de cuántos sale, y que la tasa de acierto
   no cuenta los que siguen sin contestar.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e11.js            */
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

/* Catálogo mínimo y un escenario, para que calcularEstimado dé un número. */
const CAT = [{ id: 1, item: '20A DUPLEX RECEPTACLE', seccion: 'WIRING DEVICES', precio: 4, horas_unidad: 0.5, unidad: 'E' }];
/* OJO con la escala: en Supabase los porcentajes van en FRACCIÓN (0.16 = 16 %),
   igual que los defaults del motor. Este fixture los tenía como enteros y el
   bid salía por las nubes (profit 12 = 1.200 %) — se veía al meterle ítems de
   verdad. El motor no tiene la culpa; el fixture sí la tenía. */
const ESC = [{ id: 'B', nombre: 'Mercado', foreman: 45, journeyman: 35, helper: 20,
               pct_foreman: 0.2, pct_journeyman: 0.5, pct_helper: 0.3,
               benefits: 0.16, tax_material: 0.075, overhead_hh: 12, profit: 0.12 }];
/* Seis estimados con historia. Los tres primeros llevan FOTO (bid_final):
   son los que cuentan de verdad. */
const EST = [
  { id: 'a', nombre: 'Casa Roberto',  sqft: 2400, modo: 'remodelacion', escenario: 'B', estado: 'convertido',
    resultado: 'ganado',  bid_final: 21600, horas_final: 240, material_final: 6000 },
  { id: 'b', nombre: 'Casa Marta',    sqft: 3000, modo: 'remodelacion', escenario: 'B', estado: 'convertido',
    resultado: 'ganado',  bid_final: 28500, horas_final: 310, material_final: 7800 },
  { id: 'c', nombre: 'Casa Luis',     sqft: 2000, modo: 'remodelacion', escenario: 'B', estado: 'congelado',
    resultado: 'ganado',  bid_final: 16000, horas_final: 190, material_final: 4400 },
  { id: 'd', nombre: 'Duplex Ocean',  sqft: 2500, modo: 'remodelacion', escenario: 'B', estado: 'congelado',
    resultado: 'perdido', resultado_motivo: 'precio', competencia: 20000, bid_final: 26000, horas_final: 280 },
  { id: 'e', nombre: 'Shop Kendall',  sqft: 9000, modo: 'planos', escenario: 'B', estado: 'congelado',
    resultado: 'perdido', resultado_motivo: 'plazo', bid_final: 74000, horas_final: 800 },
  { id: 'f', nombre: 'Oficina NW',    sqft: 6000, modo: 'planos', escenario: 'B', estado: 'borrador' },
  { id: 'g', nombre: 'Torre MEP',     sqft: 40000, modo: 'planos', escenario: 'MEP', empresa: 'mep', estado: 'congelado',
    resultado: 'ganado', bid_final: 410000, horas_final: 4200 },
  { id: 'h', nombre: 'Sin cerrar',    sqft: 2200, modo: 'remodelacion', escenario: 'B', estado: 'congelado',
    resultado: 'sin_respuesta' }
];

(async () => {
  await new Promise(r => srv.listen(8861, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8861/index.html'); await p.waitForTimeout(1200);
  await p.evaluate(d => window.MXP_PRUEBA.e11.datos(d), { catalogo: CAT, escenarios: ESC, estimados: EST, items: [], config: {} });

  /* === 1. la foto: un dato no es una suposición === */
  const f1 = await p.evaluate(e => window.MXP_PRUEBA.e11.foto(e), EST[0]);
  ok('un estimado con foto usa SU número, el del día que se ofertó', f1.bid === 21600 && f1.recalculado === false, JSON.stringify(f1));
  const f2 = await p.evaluate(e => window.MXP_PRUEBA.e11.foto(e), EST[5]);
  ok('uno sin foto se recalcula con los precios de hoy, y lo dice', f2.recalculado === true, JSON.stringify(f2));
  const guarda = await p.evaluate(e => window.MXP_PRUEBA.e11.guardar(e), { id: 'x', sqft: 100, escenario: 'B', modo: 'remodelacion' });
  ok('al cerrar se guarda bid, horas y material, con la fecha', 'bid_final' in guarda && 'horas_final' in guarda && 'material_final' in guarda && /^\d{4}-/.test(guarda.cerrado_en), JSON.stringify(guarda).slice(0, 90));

  /* === 2. los tramos separan los cuatro negocios === */
  const tr = await p.evaluate(() => [900, 2400, 9000, 40000, 0].map(s => window.MXP_PRUEBA.e11.tramo(s)));
  ok('los tramos por tamaño separan reforma, casa, mediano y grande', tr.join() === 'chico,casa,mediano,grande,', JSON.stringify(tr));

  /* === 3. el resumen === */
  const bm = await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e), EST);
  ok('los de MXP MEP no se mezclan con los tuyos por defecto', bm.total === 8, 'total=' + bm.total);
  const mios = await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e, { empresa: 'mxp' }), EST);
  ok('pidiendo solo los tuyos, la torre del MEP se queda fuera', mios.total === 7, 'total=' + mios.total);
  const mep = await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e, { empresa: 'mep' }), EST);
  ok('y pidiendo los del MEP, sale solo esa', mep.total === 1 && mep.porResultado.ganado.n === 1, 'total=' + mep.total);

  ok('cuenta ganados y perdidos por separado', mios.porResultado.ganado.n === 3 && mios.porResultado.perdido.n === 2,
    JSON.stringify({ g: mios.porResultado.ganado.n, p: mios.porResultado.perdido.n }));
  ok('y dice cuántos siguen sin decidir, en vez de esconderlos', mios.sinDecidir === 1, 'sinDecidir=' + mios.sinDecidir);
  ok('la tasa de acierto NO cuenta el que no ha contestado (3 de 5, no 3 de 6)',
    Math.abs(mios.todo.tasa - 3 / 5) < 1e-9 && mios.todo.decididos === 5, 'tasa=' + mios.todo.tasa + ' decididos=' + mios.todo.decididos);

  /* === 4. $/SF: la cuenta, y con cuántos === */
  const g = mios.porResultado.ganado;
  const psfEsperado = (21600 / 2400 + 28500 / 3000 + 16000 / 2000) / 3;   // 9 + 9.5 + 8 = 8.833…
  ok('el $/SF medio de los ganados sale de sus fotos (9 · 9,5 · 8 → 8,83)',
    Math.abs(g.psfMedio - psfEsperado) < 1e-9, g.psfMedio.toFixed(3));
  ok('y también la mediana, que es la que aguanta un trabajo raro', Math.abs(g.psfMediana - 9) < 1e-9, String(g.psfMediana));
  ok('siempre se dice de cuántos sale la media', g.psfN === 3 && g.n === 3, JSON.stringify({ psfN: g.psfN, n: g.n }));
  ok('las horas por pie también (240/2400 = 0,1)', Math.abs(g.hsfMedio - (240 / 2400 + 310 / 3000 + 190 / 2000) / 3) < 1e-9, g.hsfMedio.toFixed(4));
  ok('ninguno de los ganados es recalculado: los tres tienen foto', g.recalculados === 0, 'recalculados=' + g.recalculados);
  const sinFoto = await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e, { empresa: 'mxp' }).todo.recalculados, EST);
  ok('y se dice cuántos del total SÍ son recalculados (los 2 sin foto)', sinFoto === 2, 'recalculados=' + sinFoto);

  /* === 5. por tramo y por modo === */
  const casa = mios.porTramo.find(t => t.tramo === 'casa');
  // los cinco tuyos entre 1.500 y 5.000: Roberto 2400, Marta 3000, Luis 2000, Ocean 2500 y el Sin cerrar 2200
  ok('el tramo de casa junta los cinco de 1.500–5.000 sqft, ganados o no', casa && casa.n === 5, JSON.stringify(mios.porTramo.map(t => [t.tramo, t.n])));
  ok('y dentro de ese tramo, la tasa sale de los decididos (3 de 4)', Math.abs(casa.tasa - 3 / 4) < 1e-9 && casa.decididos === 4, JSON.stringify({ tasa: casa.tasa, dec: casa.decididos }));
  ok('los de planos van en su propio modo', (mios.porModo.find(m => m.modo === 'planos') || {}).n === 2, JSON.stringify(mios.porModo.map(m => [m.modo, m.n])));

  /* === 6. lo que de verdad calibra: cuánto se falló === */
  ok('con el número del que ganó, se dice cuánto de caro se iba (26.000 vs 20.000 = +30 %)',
    mios.brecha && mios.brecha.n === 1 && Math.abs(mios.brecha.medio - 0.30) < 1e-9, JSON.stringify(mios.brecha));
  ok('los motivos de los perdidos se cuentan', mios.motivos.precio === 1 && mios.motivos.plazo === 1, JSON.stringify(mios.motivos));

  /* === 7. el aviso de «te sales de lo que sueles cobrar» === */
  const caro = await p.evaluate(e => window.MXP_PRUEBA.e11.rango({ id: 'nuevo', sqft: 2400, escenario: 'B', modo: 'remodelacion', bid_final: 999999 }, e), EST);
  ok('compara contra los GANADOS de su mismo tramo, no contra todo', caro && caro.pocos === false && caro.n === 3, JSON.stringify({ n: caro.n, pocos: caro.pocos }));
  ok('y contra la mediana (9 $/SF), diciendo el mínimo y el máximo que has cobrado',
    Math.abs(caro.mediana - 9) < 1e-9 && Math.abs(caro.min - 8) < 1e-9 && Math.abs(caro.max - 9.5) < 1e-9, JSON.stringify({ med: caro.mediana, min: caro.min, max: caro.max }));
  const pocos = await p.evaluate(e => window.MXP_PRUEBA.e11.rango({ id: 'n2', sqft: 9000, escenario: 'B' }, e), EST);
  ok('con menos de tres parecidos NO se inventa un rango: dice que son pocos', pocos && pocos.pocos === true, JSON.stringify(pocos));
  const sinSqft = await p.evaluate(e => window.MXP_PRUEBA.e11.rango({ id: 'n3', escenario: 'B' }, e), EST);
  ok('sin sqft no hay $/SF que comparar, y se calla', sinSqft === null, JSON.stringify(sinSqft));

  /* === 8. nada de esto mueve un centavo de un estimado === */
  const antes = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e).bid, { id: 'z', sqft: 2400, escenario: 'B', modo: 'remodelacion' });
  await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e), EST);
  const despues = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e).bid, { id: 'z', sqft: 2400, escenario: 'B', modo: 'remodelacion' });
  ok('mirar el historial no cambia lo que vale un estimado', antes === despues, antes + ' → ' + despues);

  /* === 9. lista vacía === */
  const vacio = await p.evaluate(() => window.MXP_PRUEBA.e11.bench([]));
  ok('sin estimados no se rompe ni inventa medias', vacio.total === 0 && vacio.todo === null, JSON.stringify(vacio).slice(0, 80));

  /* === 10. la pantalla se pinta y dice lo que tiene que decir === */
  const pant = await p.evaluate(() => {
    const d = document.createElement('div');
    d.innerHTML = window.MXP_PRUEBA.e11.tarjeta ? window.MXP_PRUEBA.e11.tarjeta() : '';
    return d.textContent.replace(/\s+/g, ' ').trim();
  });
  ok('el historial se pinta con el total y la tasa', /Historial/.test(pant) && /7 estimados/.test(pant) && /ganas 60 %/.test(pant), pant.slice(0, 110));
  ok('y avisa de los que salen recalculados con precios de hoy', /2 de 7/.test(pant) && /recalculados con los precios de hoy/.test(pant), pant.slice(0, 200));
  ok('la tabla por tamaño pone «—» donde no hay tres con que comparar', /—/.test(pant), pant.slice(-160));
  ok('dice que es mediana, no media', /Mediana, no media/.test(pant), pant.slice(-120));
  ok('y una tasa de acierto sacada de UNA oferta no se enseña: sale «—»',
    !/sqft ?2 ?— ?— ?0 %/.test(pant.replace(/\s+/g, ' ')), pant.slice(-230));

  /* === 11. lo que le pasó a Edgar de verdad (15/09): sus 3 convertidos
         quedaron con foto pero SIN pies cuadrados, así que no hay $/sqft.
         Eso tiene que verse y tiene que poder arreglarse. === */
  const SIN_SQFT = [
    { id: 'x1', nombre: 'Uno',  escenario: 'B', modo: 'remodelacion', estado: 'convertido', resultado: 'ganado', bid_final: 12000, horas_final: 140 },
    { id: 'x2', nombre: 'Dos',  escenario: 'B', modo: 'remodelacion', estado: 'convertido', resultado: 'ganado', bid_final: 18000, horas_final: 200 },
    { id: 'x3', nombre: 'Tres', escenario: 'B', modo: 'remodelacion', estado: 'convertido', resultado: 'ganado', bid_final: 9000,  horas_final: 100 }
  ];
  const bSin = await p.evaluate(e => window.MXP_PRUEBA.e11.bench(e), SIN_SQFT);
  ok('con fotos pero sin sqft, el $/sqft sale vacío en vez de inventado', bSin.todo.psfN === 0 && bSin.todo.psfMedio === null, JSON.stringify({ n: bSin.todo.n, psfN: bSin.todo.psfN }));
  ok('y aun así se cuentan bien los ganados', bSin.porResultado.ganado.n === 3, String(bSin.porResultado.ganado.n));
  await p.evaluate(d => window.MXP_PRUEBA.e11.datos(d), { catalogo: CAT, escenarios: ESC, estimados: SIN_SQFT, items: [], config: {} });
  const avisoSin = await p.evaluate(() => { const d = document.createElement('div'); d.innerHTML = window.MXP_PRUEBA.e11.tarjeta(); return d.textContent.replace(/\s+/g, ' '); });
  ok('el historial avisa de que sin pies cuadrados no compara nada, y dice dónde ponerlos',
    /Ninguno tiene pies cuadrados/.test(avisoSin) && /¿Cómo acabó\?/.test(avisoSin), avisoSin.slice(0, 180));

  /* los pies cuadrados se pueden poner DESPUÉS: antes solo se podían al crear
     el estimado, así que todo lo viejo se quedaba sin $/sqft para siempre */
  const bloqueSin = await p.evaluate(() => { const d = document.createElement('div'); d.innerHTML = window.MXP_PRUEBA.e11.bloque({ id: 'x1', nombre: 'Uno', escenario: 'B', modo: 'remodelacion', resultado: 'ganado', bid_final: 12000 }); return { html: d.innerHTML, txt: d.textContent.replace(/\s+/g, ' ') }; });
  ok('el bloque «¿Cómo acabó?» deja escribir los pies cuadrados de un trabajo viejo',
    /id="est-sqft"/.test(bloqueSin.html) && /aunque el trabajo sea viejo/.test(bloqueSin.txt), bloqueSin.txt.slice(0, 150));
  const bloqueCon = await p.evaluate(() => { const d = document.createElement('div'); d.innerHTML = window.MXP_PRUEBA.e11.bloque({ id: 'x1', sqft: 2000, escenario: 'B', modo: 'remodelacion', resultado: 'ganado', bid_final: 18000 }); return d.textContent.replace(/\s+/g, ' '); });
  ok('y con ellos puestos, enseña a cuánto sale el pie CON EL NÚMERO QUE OFERTÓ, no con el de hoy',
    /\$9\.00\/sqft/.test(bloqueCon) && /con el número que ofertaste/.test(bloqueCon), bloqueCon.slice(0, 160));

  /* --- CONVERTIDO SIN FOTO (16/09): el numero se recalcula y hay que poder congelarlo --- */
  /* un convertido de los viejos: con ítems de verdad, para que el bid no sea 0 */
  await p.evaluate(([cat, esc]) => window.MXP_PRUEBA.e11.datos({
    catalogo: cat, escenarios: esc, config: {},
    estimados: [{ id: 99, nombre: 'Ya vendido', estado: 'convertido', escenario: 'B', factor: 1 }],
    items: [{ id: 1, estimado_id: 99, item: '20A DUPLEX RECEPTACLE', unidad: 'E', precio: 4, horas: 0.5, cantidad: 40 }]
  }), [CAT, ESC]);
  const vendidoSinFoto = await p.evaluate(() => {
    const est = { id: 99, nombre: 'Ya vendido', estado: 'convertido', escenario: 'B', factor: 1 };
    const f1 = window.MXP_PRUEBA.e11.foto(est);
    return { recalculado: f1.recalculado, antes: f1.bid };
  });
  ok('el convertido de prueba tiene número: 40 receptáculos (160 + 20 h) dan un bid con los pies en la tierra',
    vendidoSinFoto.antes > 500 && vendidoSinFoto.antes < 5000, '$' + Math.round(vendidoSinFoto.antes));
  ok('un convertido SIN foto se recalcula (por eso el número de un trabajo vendido puede moverse)', vendidoSinFoto.recalculado === true, JSON.stringify(vendidoSinFoto));
  const conFoto = await p.evaluate(() => {
    const est = { id: 99, nombre: 'Ya vendido', estado: 'convertido', escenario: 'B', factor: 1 };
    const guardar = window.MXP_PRUEBA.e11.guardar(est);
    const congelado = Object.assign({}, est, guardar);
    const f2 = window.MXP_PRUEBA.e11.foto(congelado);
    return { guardar, recalculado: f2.recalculado, bid: f2.bid, tieneFecha: !!guardar.cerrado_en };
  });
  ok('congelarlo guarda bid, horas, material y la fecha, y a partir de ahí ya no se recalcula',
    conFoto.recalculado === false && conFoto.guardar.bid_final > 0 && conFoto.guardar.horas_final > 0 && conFoto.tieneFecha,
    JSON.stringify(conFoto.guardar));
  ok('y el número congelado es exactamente el que se enseñaba antes de congelar', conFoto.bid === conFoto.guardar.bid_final, conFoto.bid + ' = ' + conFoto.guardar.bid_final);

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(x => x.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' ok'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
