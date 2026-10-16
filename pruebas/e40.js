/* E40 · EL TAKEOFF POR SECCIONES (29/09). Edgar: «todo está regado: lo mismo
   te aparece una luz en la primera fila que una tubería en la veintitrés…
   como en Bluebeam y en el Excel, por categorías… y en cada sección, los
   automáticos que se incluyen». La lista de ítems del estimado y el «Ver el
   takeoff para copiar» van por secciones, en el orden de la obra. Manda la
   sección del catálogo (la del Excel) y el nombre; el código de partida, que
   dice DÓNDE se contó, solo si no hay otra cosa. Solo la vista: el dinero no
   se mueve y la columna del takeoff sigue sumando de arriba abajo.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e40.js          */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json' };
const srv = http.createServer((req, res) => { let p = req.url.split('?')[0]; if (p === '/') p = '/index.html'; fs.readFile(path.join(ROOT, p), (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d); }); });
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));
// el catálogo de Edgar en corto, con sus secciones de verdad
const C = (item, seccion, unidad, precio, horas_unidad, codigo) => ({ item, seccion, unidad, precio, horas_unidad, codigo });
const CAT = [
  C('# 12      THHN STRANDED CU.', 'WIRING', 'MLF', 350, 6, '08-ROUGH'), C('#12     GROUND PIGTAIL', 'WIRING', 'E', 0.17, 0.01, '08-ROUGH'),
  C('1/2"     EMT CONDUIT', 'RACEWAY', 'LF', 0.6124, 0.03, '09-COND'), C('3/4"     EMT CONDUIT', 'RACEWAY', 'LF', 1.0903, 0.04, '09-COND'),
  C('1/2"       EMT S.S. D/C CONNECTOR', 'RACEWAY', 'E', 1.1679, 0.06, '09-COND'), C('3/4"       EMT S.S. D/C CONNECTOR', 'RACEWAY', 'E', 1.8074, 0.07, '09-COND'),
  C('1/2"       EMT S.S. D/C COUPLING', 'RACEWAY', 'E', 0.4529, 0.04, '09-COND'), C('3/4"       EMT S.S. D/C COUPLING', 'RACEWAY', 'E', 0.4336, 0.045, '09-COND'),
  C('1/2"      EMT STRAP 1 HOLE STRAP', 'RACEWAY', 'E', 0.1459, 0.02, '09-COND'), C('3/4"      EMT STRAP 1 HOLE STRAP', 'RACEWAY', 'E', 0.2045, 0.022, '09-COND'),
  C('JB 1900 BOX', 'RACEWAY', 'E', 1.04, 0.25, '09-COND'), C('CEILING RING  1/2"', 'RACEWAY', 'E', 0.599, 0.1, '09-COND'), C('T-BAR BOX HANGER', 'RACEWAY', 'E', 1.06, 0.05, '09-COND'),
  C('4"X4" BLANK COVER', 'RACEWAY', 'E', 0.804, 0.07, '09-COND'), C('TAPCON 1/4" x 1-1/4"', 'RACEWAY', 'E', 0.35, 0.008, '09-COND'),
  C('4" RECESSED CAN LIGHT', 'LIGHTING FIXTURES', 'E', 172, 0.75, '11-LIGHT'), C('W.P SPLICES', 'LIGHTING FIXTURES', 'E', 2, 0.15, '11-LIGHT'),
  C('20A DUPLEX RECEPTACLE', 'WIRING DEVICES', 'E', 1.44, 0.4, '10-DEV'), C('BREAKER 1P 20A', 'BREAKERS', 'E', 8, 0.25, '05-PANEL'),
  C('YELLOW WIRENUTS', 'MISCELLANEOUS', 'E', 0.26, 0, '08-ROUGH'), C('ELECTRICAL TAPE 3/4" x 66FT', 'MISCELLANEOUS', 'E', 1.5, 0, '20-MISC'),
  C('WIRE PULLING LUBRICANT 1 QT', 'MISCELLANEOUS', 'E', 9, 0, '20-MISC'), C('WIRE MARKER BOOK', 'MISCELLANEOUS', 'E', 12, 0, '20-MISC'),
  C('18/2 SHIELDED FIRE ALARM CABLE', 'FIRE ALARM', 'MLF', 60, 8, '13-LV'), C('DEMO - Light Fixtures', 'DEMOLITION', 'EA', 0, 0.3, '01-DEMO'),
  C('LED TRANSFORMER (60W 24V driver)', 'LIGHTING FIXTURES', 'E', 45, 0.5, '11-LIGHT'), C('PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)', 'LABOR', 'E', 0, 0.25, '11-LIGHT')
];
const ESC = [{ id: 'MEP', foreman: 43, journeyman: 34, helper: 22, pct_foreman: .2, pct_journeyman: .5, pct_helper: .3, benefits: .28, tax_material: .07, overhead_hh: 0, overhead_pct: 0.15, profit: .15 }];
// Peninsula, en el orden REGADO en que llega de Planos: la luz primero, el tubo en medio, la caja al final
const I = (id, item, cantidad, precio, horas, unidad, codigo) => ({ id, estimado_id: 44, item, cantidad, precio, horas, unidad, codigo, origen: 'takeoff' });
const ITEMS = [
  I(1, '4" RECESSED CAN LIGHT', 85, 0, 0.75, 'E', '11-LIGHT'), I(2, '# 12      THHN STRANDED CU.', 2.995, 350, 6, 'MLF', '08-ROUGH'),
  I(3, '1/2"       EMT S.S. D/C CONNECTOR', 270, 1.1679, 0.06, 'E', '11-LIGHT'), I(4, 'BREAKER 1P 20A', 13, 8, 0.25, 'E', '05-PANEL'),
  I(5, '1/2"     EMT CONDUIT', 1110, 0.6124, 0.03, 'LF', '08-ROUGH'), I(6, '3/4"     EMT CONDUIT', 198, 1.0903, 0.04, 'LF', '08-ROUGH'),
  I(7, 'YELLOW WIRENUTS', 381, 0.26, 0, 'E', '11-LIGHT'), I(8, 'DEMO - Light Fixtures', 168, 0, 0.3, 'EA', '01-DEMO'),
  I(9, 'W.P SPLICES', 24, 2, 0.15, 'E', '11-LIGHT'), I(10, '20A DUPLEX RECEPTACLE', 98, 1.44, 0.4, 'E', '10-DEV'),
  I(11, 'JB 1900 BOX', 127, 1.04, 0.25, 'E', '11-LIGHT'), I(12, 'Cosa rara a mano', 3, 10, 0.5, 'E', '20-MISC'),
  I(13, 'Recessed Light', 2, 0, 0.75, 'E', '11-LIGHT')
];
const EST = { id: 44, nombre: 'Peninsula', escenario: 'MEP', modo: 'planos', estado: 'borrador', factor: 1, markup_pct: 0.2 };

(async () => {
  await new Promise(r => srv.listen(8940, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const p = await (await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' })).newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.route(/supabase\.co/, r => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }));
  await p.goto('http://localhost:8940/index.html'); await p.waitForFunction(() => window.MXP_PRUEBA && window.MXP_PRUEBA.e0, null, { timeout: 15000 });
  await p.evaluate(([c, e, it, est]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: { misc_pct: 0.03 }, items: it, estimados: [est], ensambles: [], estEnsambles: [] }), [CAT, ESC, ITEMS, EST]);

  /* === 1. de qué sección es cada cosa === */
  const sec = await p.evaluate(it => it.map(x => window.MXP_PRUEBA.seccionTakeoff(x)), ITEMS);
  const de = n => sec[ITEMS.findIndex(x => x.item === n)];
  ok('el conector de 1/2" abierto de la receta de una luz (11-LIGHT) es TUBERÍA, no iluminación', de('1/2"       EMT S.S. D/C CONNECTOR') === 'tuberia');
  ok('los wirenuts contados con la luz son CABLEADO', de('YELLOW WIRENUTS') === 'cable');
  ok('la caja 1900 contada con la luz es CAJAS', de('JB 1900 BOX') === 'cajas');
  ok('los W.P SPLICES son cableado aunque el catálogo los tenga con la luz', de('W.P SPLICES') === 'cable');
  ok('THHN → cableado · tubo → tubería · breaker → paneles · receptáculo → dispositivos · can → iluminación · DEMO → demolición',
    [de('# 12      THHN STRANDED CU.'), de('1/2"     EMT CONDUIT'), de('BREAKER 1P 20A'), de('20A DUPLEX RECEPTACLE'), de('4" RECESSED CAN LIGHT'), de('DEMO - Light Fixtures')].join(',') === 'cable,tuberia,panel,disp,luz,demo', sec.join(','));
  ok('sin catálogo: por el nombre («Recessed Light» → iluminación) y si no, por la partida (20-MISC → otros)', de('Recessed Light') === 'luz' && de('Cosa rara a mano') === 'otros');
  const mas = await p.evaluate(() => ['18/2 SHIELDED FIRE ALARM CABLE', 'LED TRANSFORMER (60W 24V driver)', 'PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)', 'ELECTRICAL TAPE 3/4" x 66FT', 'TAPCON 1/4" x 1-1/4"', '4"X4" BLANK COVER']
    .map(n => window.MXP_PRUEBA.seccionTakeoff({ item: n })).join(','));
  ok('el cable de fire alarm es bajo voltaje · el driver LED es iluminación (no paneles) · la puesta en marcha es mano de obra · tape → cableado · tapcon → tubería · tapa ciega → cajas',
    mas === 'lv,luz,mano,cable,tuberia,cajas', mas);

  /* === 2. el editor: la lista por secciones, en el orden de la obra, con los automáticos dentro === */
  const ed = await p.evaluate(() => { const r = window.MXP_PRUEBA.e0.editor(44);
    const secs = [...document.querySelectorAll('#estimador-panel .tk-sec')].map(x => ({ id: x.dataset.sec, txt: x.innerText.replace(/\s+/g, ' ') }));
    // qué renglones cuelgan de cada sección
    const cuelgan = {}; let ahora = null;
    [...document.querySelectorAll('#estimador-panel .tk-sec, #estimador-panel .mat-item')].forEach(x => {
      if (x.classList.contains('tk-sec')) { ahora = x.dataset.sec; cuelgan[ahora] = []; }
      else if (ahora && x.closest('.cal-panel-card') === document.querySelector('#estimador-panel .tk-sec').closest('.cal-panel-card'))
        cuelgan[ahora].push((x.classList.contains('auto-item') ? 'AUTO ' : '') + (x.querySelector('.alcance-titulo') || x).innerText.split('—')[0].replace(/\s+/g, ' ').trim());
    });
    return { secs, cuelgan, ids: r.ids };
  });
  ok('las secciones salen en el orden de la obra: tubería, cableado, cajas, dispositivos, iluminación, paneles, demolición, otros',
    ed.secs.map(x => x.id).join(',') === 'tuberia,cable,cajas,disp,luz,panel,demo,otros', ed.secs.map(x => x.id).join(','));
  ok('la tubería lleva sus tubos y el conector de la luz, y sus AUTOMÁTICOS (acoples, conectores y grapas de 3/4")',
    ed.cuelgan.tuberia && ed.cuelgan.tuberia.some(x => /^1\/2" EMT CONDUIT/.test(x)) && ed.cuelgan.tuberia.some(x => /^1\/2" EMT S\.S\. D\/C CONNECTOR/.test(x))
      && ed.cuelgan.tuberia.some(x => /^AUTO 3\/4" EMT S\.S\. D\/C COUPLING/.test(x)) && ed.cuelgan.tuberia.some(x => /^AUTO TAPCON/.test(x)), JSON.stringify(ed.cuelgan.tuberia));
  ok('el cableado lleva el THHN, los wirenuts, los splices y sus automáticos (tape, grasa, libreta)',
    ed.cuelgan.cable && ['THHN', 'WIRENUTS', 'W.P SPLICES', 'AUTO ELECTRICAL TAPE', 'AUTO WIRE PULLING', 'AUTO WIRE MARKER'].every(k => ed.cuelgan.cable.some(x => x.includes(k))), JSON.stringify(ed.cuelgan.cable));
  ok('las cajas llevan la 1900 y la tapa ciega automática', ed.cuelgan.cajas && ed.cuelgan.cajas.some(x => /JB 1900 BOX/.test(x)) && ed.cuelgan.cajas.some(x => /^AUTO 4"X4" BLANK COVER/.test(x)), JSON.stringify(ed.cuelgan.cajas));
  ok('ninguna luz se cuela en la tubería ni un tubo en la iluminación', !ed.cuelgan.tuberia.some(x => /LIGHT/.test(x)) && !(ed.cuelgan.luz || []).some(x => /EMT|CONDUIT/.test(x)));
  const tub = ed.secs.find(x => x.id === 'tuberia');
  ok('cada sección dice cuántos renglones, cuántos automáticos, sus horas y su total', /Tubería y fittings \d+ renglones \+ \d+ automáticos · [\d.]+ h \$[\d,]+\.\d\d/.test(tub.txt), tub.txt);

  /* === 3. el dinero no se mueve === */
  const suma = await p.evaluate(() => { const c = window.MXP_PRUEBA.e0.calcula((window.__e = { id: 44, nombre: 'Peninsula', escenario: 'MEP', modo: 'planos', estado: 'borrador', factor: 1, markup_pct: 0.2 }));
    const tot = [...document.querySelectorAll('#estimador-panel .tk-sec-tot')].reduce((t, x) => t + (Number(x.innerText.replace(/[$,—]/g, '')) || 0), 0);
    const base = c.items.reduce((t, i) => t + i.cantidad * i.precio, 0) + c.autos.reduce((t, a) => t + a.cantidad * a.precio, 0);
    return { tot, base }; });
  ok('la suma de las secciones es el material de los renglones + automáticos, al centavo', Math.abs(suma.tot - suma.base) < 0.05 * 8, suma.tot.toFixed(2) + ' vs ' + suma.base.toFixed(2));

  /* === 4. el takeoff para copiar, por secciones, y sigue cuadrando === */
  const tk = await p.evaluate(e => window.MXP_PRUEBA.e0.takeoff(e, window.MXP_PRUEBA.e0.calcula(e)), EST);
  const filas = tk.split('\n').map(x => x.split('\t'));
  const cab = filas.findIndex(x => x[0] === 'Partida'), blanco = filas.findIndex((x, i) => i > cab && x.length === 1 && x[0] === '');
  const cuerpo = filas.slice(cab + 1, blanco);
  const heads = cuerpo.filter(x => /^── /.test(x[1])).map(x => x[1].split(' ── ')[0].replace('── ', ''));
  ok('el takeoff para copiar va por secciones, con su encabezado, en el mismo orden', heads.join(',') === 'TUBERÍA Y FITTINGS,CABLEADO,CAJAS Y ANILLOS,DISPOSITIVOS,ILUMINACIÓN,PANELES Y BREAKERS,DEMOLICIÓN,OTROS', heads.join(','));
  ok('el encabezado dice renglones, dinero y horas de su sección, y deja vacía la columna de dinero', cuerpo.filter(x => /^── /.test(x[1])).every(x => / (renglón|renglones) · \$[\d,]+\.\d\d · [\d.]+ h$/.test(x[1]) && x[7] === ''), cuerpo.filter(x => /^── /.test(x[1])).map(x => x[1] + '|' + x[7]).join(' / '));
  const sumaCol = cuerpo.reduce((t, x) => t + (Number(x[7]) || 0), 0);
  const matR = filas.find(x => x[1] === 'Material de los renglones');
  ok('la columna de dinero sigue sumando «Material de los renglones» (el encabezado no cuenta doble)', Math.abs(sumaCol - Number(matR[7])) < 0.05, sumaCol.toFixed(2) + ' vs ' + matR[7]);
  const primero = cuerpo.findIndex(x => /1\/2" +EMT CONDUIT/.test(x[1])), luz = cuerpo.findIndex(x => /RECESSED CAN LIGHT/.test(x[1]));
  ok('el tubo sale antes que la luz (ya no «una luz en la primera fila y el tubo en la veintitrés»)', primero > 0 && luz > primero, primero + ' < ' + luz);

  ok('sin errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('E40 · EL TAKEOFF POR SECCIONES\n' + R.join('\n'));
  const mal = R.filter(x => x.startsWith('  ✗')).length;
  console.log(mal ? '\n' + mal + ' FALLAN' : '\nTODO BIEN (' + R.length + ')');
  await b.close(); srv.close(); process.exit(mal ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
