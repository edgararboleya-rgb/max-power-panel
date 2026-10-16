/* E37 · Tanda 3 de Mariners (23/09): los DATOS DEL TRABAJO (contratante, dueño
   final, dirección, retención), los hitos con la retención aparte y al cierre,
   y que las propuestas lo digan.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e37.js          */

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
  await new Promise(r => srv.listen(8868, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8868/index.html'); await p.waitForTimeout(500);
  const ITEMS = [{ id: 1, estimado_id: 7, item: 'CAJA', cantidad: 100, precio: 10, horas: 0.5, unidad: 'EA', orden: 1 }];
  await p.evaluate(([c, e, cf, it]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it, estimados: [], ensambles: [], estEnsambles: [] }), [CAT, ESC, CFG, ITEMS]);
  const calc = est => p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), est);
  const hitos = (bid, ret) => p.evaluate(([b, r]) => window.MXP_PRUEBA.e0.hitos(b, r), [bid, ret]);

  /* === 1. los hitos === */
  const sin = await hitos(100000, 0);
  // (26/09) el reparto ya no es 35/40/25 fijo: lo decide la IA según la obra (v228, la otra sesión).
  // Lo que se comprueba aquí es lo de la retención, sea cual sea el reparto.
  const suma = l => Math.round(l.reduce((s, h) => s + h.monto, 0) * 100) / 100;
  ok('sin retención: los hitos suman el contrato y ninguno es retención', suma(sin) === 100000 && !sin.some(h => /Retainage/.test(h.titulo)), sin.map(h => h.monto).join('/'));
  const con = await hitos(100000, 0.10);
  const ult = con[con.length - 1];
  ok('con 10 % de retención: los pagos suman el 90 % y cada uno es el 90 % del de sin retención', suma(con.slice(0, -1)) === 90000 && con.length === sin.length + 1 && con.slice(0, -1).every((h, i) => Math.abs(h.monto - sin[i].monto * 0.9) < 0.02), con.map(h => h.monto).join('/'));
  ok('y la retención es el último hito, al cierre', ult.monto === 10000 && /cierre/.test(ult.condicion) && /Retainage — 10%/.test(ult.titulo), JSON.stringify(ult));
  const raro = await hitos(123456.78, 0.075);
  ok('suman el contrato al centavo, con cualquier número', Math.abs(raro.reduce((s, h) => s + h.monto, 0) - 123456.78) < 0.005, raro.map(h => h.monto).join(' + '));

  /* === 2. la propuesta de Max Power === */
  const EST = { id: 7, nombre: 'Mariners Hospital Chillers Replacement', cliente: 'Integrated Systems', dueno: 'Baptist Health',
    direccion: '91500 Overseas Hwy, Tavernier FL', retencion_pct: 0.10, escenario: 'B', modo: 'planos', estado: 'borrador', factor: 1 };
  const c = await calc(EST);
  const prop = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propuesta(e, c), [EST, c]);
  ok('la propuesta dice la obra y el dueño', /Obra: 91500 Overseas Hwy/.test(prop) && /Dueño \/ Owner: Baptist Health/.test(prop));
  ok('y la retención en la forma de pago, con su monto', /Retención del contratante — 10% de cada pago, se libera al cierre/.test(prop), (prop.match(/Retención.*$/m) || [''])[0]);
  const sinRet = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propuesta(e, c), [{ ...EST, retencion_pct: null, dueno: null, direccion: null }, c]);
  ok('sin esos datos, la propuesta no dice retención, dueño ni obra', !/Retención|Dueño|Obra:/.test(sinRet) && /PRECIO TOTAL/.test(sinRet));

  /* === 3. el papel de MXP MEP === */
  const mep = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propMep(e, c), [{ ...EST, empresa: 'mep' }, c]);
  ok('el papel en inglés dice la obra, el dueño y el retainage', /Project location: 91500/.test(mep) && /Owner: Baptist Health/.test(mep) && /Retainage: 10% withheld/.test(mep));

  /* === 4. la tarjeta === */
  const html = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetaDatos(e), EST);
  ok('la tarjeta trae contratante, dueño, dirección y retención con sus valores',
    /id="est-dat-cliente" value="Integrated Systems"/.test(html) && /id="est-dat-dueno" value="Baptist Health"/.test(html) &&
    /id="est-dat-dir" value="91500 Overseas Hwy, Tavernier FL"/.test(html) && /id="est-dat-ret"[^>]*value="10"/.test(html));

  /* === 4b. los adjuntos === */
  const adjH = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetaAdj(e), { ...EST, adjuntos: [{ titulo: 'Cuota CED 23/09', ruta: 'docs/est-7/a.pdf', fecha: '2026-09-23' }, { titulo: 'Set de planos', url: 'https://drive.google.com/x' }, { titulo: 'roto' }] });
  ok('los adjuntos se listan: el PDF se abre firmado y el enlace directo; uno sin archivo ni enlace no sale',
    /Adjuntos del estimado \(2\)/.test(adjH) && /class="adj-abrir" data-ruta="docs\/est-7\/a.pdf"/.test(adjH) && /href="https:\/\/drive.google.com\/x"/.test(adjH) && !/roto/.test(adjH));
  const adjV = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetaAdj(e), EST);
  ok('sin adjuntos dice qué se puede poner, y trae el PDF y el enlace', /Sin adjuntos/.test(adjV) && /id="adj-archivo"/.test(adjV) && /id="adj-url"/.test(adjV));

  /* === 5. la propuesta con opciones: las líneas a mano se reparten === */
  const ESTO = { id: 9, nombre: 'Opciones', escenario: 'B', modo: 'planos', estado: 'borrador', factor: 1,
    lineas_material: [{ desc: 'Fire alarm vendor', monto: 9500, tipo: 'allow' }, { desc: 'Tubo nuevo del chiller 2', monto: 4000 }] };
  await p.evaluate(([c, e, cf, it, est]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it.map(x => ({ ...x, estimado_id: 9 })), estimados: [est], ensambles: [], estEnsambles: [] }), [CAT, ESC, CFG, ITEMS, ESTO]);
  const todoEnA = await p.evaluate(e => window.MXP_PRUEBA.e0.propOpc(9, {}), ESTO);
  const cEnt = await calc(ESTO);
  ok('con todo en A, el precio de A es el del estimado entero (nada cambia)', todoEnA.letras.join() === 'A' && Math.abs(todoEnA.precios[0] - Math.round(cEnt.bid * 100) / 100) < 0.005, todoEnA.precios[0] + ' vs ' + cEnt.bid);
  const extra = await p.evaluate(() => window.MXP_PRUEBA.e0.propOpc(9, { 'Tubo nuevo del chiller 2': 'x1' }));
  ok('una línea a mano como Extras 1: A sale SIN ella y B CON ella', extra.letras.join() === 'A,B' && extra.precios[0] < extra.precios[1] && Math.abs(extra.precios[1] - todoEnA.precios[0]) < 0.005, extra.precios.join(' / '));
  const fuera = await p.evaluate(() => window.MXP_PRUEBA.e0.propOpc(9, { 'Fire alarm vendor': 'fuera' }));
  ok('y «—» la deja fuera de todas', fuera.precios[0] < todoEnA.precios[0], fuera.precios[0] + ' < ' + todoEnA.precios[0]);

  /* === 6. el editor ENTERO se pinta, con Max Power y con MXP MEP congelado === */
  const ed = await p.evaluate(([c, e, cf, it]) => {
    const EST1 = { id: 21, nombre: 'Mariners', escenario: 'B', modo: 'planos', estado: 'borrador', factor: 1, cliente: 'Integrated Systems', dueno: 'Baptist Health', retencion_pct: 0.1,
      lineas_material: [{ desc: 'Hotel', monto: 5000, tipo: 'log' }] };
    const EST2 = { ...EST1, id: 22, empresa: 'mep', estado: 'congelado', bid_final: 25000, horas_final: 100, material_final: 9000 };
    window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: cf, items: it.map(x => ({ ...x, estimado_id: 21 })), estimados: [EST1, EST2], ensambles: [], estEnsambles: [] });
    const out = {};
    try { out.mp = window.MXP_PRUEBA.e0.editor(21); } catch (err) { out.err1 = String(err); }
    try { out.mep = window.MXP_PRUEBA.e0.editor(22); } catch (err) { out.err2 = String(err); }
    return out;
  }, [CAT, ESC, CFG, ITEMS]);
  ok('el editor de Max Power se pinta con la tarjeta de datos y los adjuntos', ed.mp && ed.mp.ids.includes('est-dat-dueno') && ed.mp.ids.includes('adj-subir') && ed.mp.ids.includes('btn-est-convertir'), ed.err1 || '');
  ok('el de MXP MEP congelado: propuesta lump sum, convertir, y datos y adjuntos editables aunque esté congelado',
    ed.mep && ed.mep.ids.includes('btn-est-prop-mep') && ed.mep.ids.includes('btn-est-convertir') && ed.mep.ids.includes('btn-est-descongelar') && ed.mep.ids.includes('est-dat-ret') && ed.mep.ids.includes('adj-subir'), ed.err2 || '');
  ok('y enseña el resultado para marcar ganado/perdido', ed.mep && ed.mep.ids.includes('est-res'));

  ok('sin errores de consola', errs.length === 0, errs.join(' // ').slice(0, 200));
  console.log(R.join('\n'));
  const fails = R.filter(l => l.indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - fails) + '/' + R.length + ' ok');
  await b.close(); srv.close(); process.exit(fails ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
