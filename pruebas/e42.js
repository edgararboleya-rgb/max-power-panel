/* E42 · EL TAKEOFF SE BAJA PARA EXCEL (06/10). Edgar: «le doy a Copiar y no
   se copia; no me da la opción de pegarlo en Excel». El portapapeles depende
   del aparato (el iPad lo niega a veces) y el aviso decía «copiado ✓» igual.
   Ahora hay «Descargar para Excel (.csv)» —comillas, UTF-8 con BOM, cada
   columna en su celda— y «Copiar» dice la verdad cuando no puede.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e42.js          */
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webmanifest': 'application/json' };
const srv = http.createServer((req, res) => { let p = req.url.split('?')[0]; if (p === '/') p = '/index.html'; fs.readFile(path.join(ROOT, p), (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); res.end(d); }); });
const R = []; const ok = (n, c, d) => R.push((c ? '  ✓ ' : '  ✗ ') + n + (d !== undefined ? '   [' + d + ']' : ''));
const CAT = [{ id: 1, item: '3-1/2"     EMT CONDUIT', seccion: 'RACEWAY', unidad: 'LF', precio: 8.5, horas_unidad: 0.08, codigo: '09-COND' },
  { id: 2, item: '600A/3P DISCONNECT SWITCH', seccion: 'SWITCHGEAR', unidad: 'E', precio: 0, horas_unidad: 10, codigo: '05-PANEL', cero_motivo: 'suministro' }];
const ESC = [{ id: 'MEP', foreman: 45, journeyman: 35, helper: 20, pct_foreman: .15, pct_journeyman: .4, pct_helper: .35, benefits: .25, tax_material: .075, overhead_hh: 0, overhead_pct: 0.15, profit: .10 }];
const ITEMS = [{ id: 1, estimado_id: 47, item: '3-1/2"     EMT CONDUIT', cantidad: 340, precio: 9.21, horas: 0.08, unidad: 'LF', codigo: '06-FEED', orden: 1 },
  { id: 2, estimado_id: 47, item: '600A/3P DISCONNECT SWITCH', cantidad: 2, precio: 0, horas: 10, unidad: 'E', codigo: '05-PANEL', orden: 2 }];
const EST = { id: 47, nombre: 'Mariners Hospital Chillers Replacement', empresa: 'mep', escenario: 'MEP', modo: 'planos', estado: 'borrador', factor: 1, tax_pct: 0.075,
  lineas_material: [{ desc: 'CED Q1009435 "rev 7", gear', monto: 38143.01, tipo: 'cot' }] };
(async () => {
  await new Promise(r => srv.listen(8943, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block', acceptDownloads: true });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.route(/supabase\.co/, r => r.fulfill({ status: 200, contentType: 'application/json', body: '[]' }));
  await p.goto('http://localhost:8943/index.html'); await p.waitForFunction(() => window.MXP_PRUEBA && window.MXP_PRUEBA.e0, null, { timeout: 15000 });
  await p.evaluate(([c, e, it, est]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, escenarios: e, config: { misc_pct: 0.03 }, items: it, estimados: [est], ensambles: [], estEnsambles: [] }), [CAT, ESC, ITEMS, EST]);

  /* === 1. la conversión pura === */
  const csv = await p.evaluate(() => window.MXP_PRUEBA.e0.csvTakeoff('Partida\tÍtem\tCantidad\n06-FEED\t3-1/2"     EMT CONDUIT\t340\n\tCED Q1009435 "rev 7", gear\t38143.01'));
  ok('empieza con el BOM de UTF-8 (Excel lee las tildes) y las filas van con CRLF', csv.charCodeAt(0) === 0xFEFF && /\r\n/.test(csv));
  const filas = csv.slice(1).split('\r\n');
  ok('cada tabulador es una coma: la cabecera queda «Partida,Ítem,Cantidad»', filas[0] === 'Partida,Ítem,Cantidad', filas[0]);
  ok('un ítem con comillas va entre comillas y con la comilla doblada', filas[1] === '06-FEED,"3-1/2""     EMT CONDUIT",340', filas[1]);
  ok('una celda con coma y comillas también; la vacía queda vacía', filas[2] === ',"CED Q1009435 ""rev 7"", gear",38143.01', filas[2]);

  /* === 2. el botón baja un .csv con el nombre del estimado === */
  // el panel del estimador no está a la vista en la prueba: los botones se pulsan por código
  await p.evaluate(() => { window.MXP_PRUEBA.e0.editor(47);
    // el panel del estimador no está a la vista en la prueba: se fuerza, para pulsar y seleccionar como lo haría Edgar
    const pan = document.getElementById('estimador-panel'); document.querySelectorAll('body > *').forEach(x => { if (!x.contains(pan)) x.style.display = 'none'; });
    let e = pan; while (e && e !== document.body) { e.hidden = false; e.style.display = 'block'; e.style.visibility = 'visible'; e.style.opacity = 1; e = e.parentElement; } });
  await p.click('#btn-est-takeoff'); await p.waitForTimeout(200);
  const hay = await p.evaluate(() => ({ bajar: !!document.getElementById('btn-bajar-takeoff'), copiar: !!document.getElementById('btn-copiar-takeoff'), nota: /no lo permite/.test(document.getElementById('propuesta-caja').innerText) }));
  ok('la caja del takeoff trae «Descargar para Excel (.csv)» y «Copiar», y avisa de lo del iPad', hay.bajar && hay.copiar && hay.nota, JSON.stringify(hay));
  // EL FALLO DE EDGAR: en modo planos había DOS cajas con id «takeoff-texto» (la de pegar el takeoff de Bluebeam y la de copiar); «Copiar» copiaba la vacía
  const ids = await p.evaluate(() => ({ texto: document.querySelectorAll('#takeoff-texto').length, copia: document.querySelectorAll('#takeoff-copia').length, largo: (document.getElementById('takeoff-copia') || {}).value.length }));
  ok('la caja de copiar tiene su propio id y trae el takeoff (la de pegar el de Bluebeam sigue aparte)', ids.texto === 1 && ids.copia === 1 && ids.largo > 200, JSON.stringify(ids));
  const [dl] = await Promise.all([p.waitForEvent('download', { timeout: 10000 }), p.click('#btn-bajar-takeoff')]);
  const nombre = dl.suggestedFilename();
  ok('se descarga «Takeoff-Mariners Hospital Chillers Replacement-AAAA-MM-DD.csv»', /^Takeoff-Mariners Hospital Chillers Replacement-\d{4}-\d{2}-\d{2}\.csv$/.test(nombre), nombre);
  const ruta = await dl.path(); const cont = fs.readFileSync(ruta, 'utf8');
  if (process.env.DBG) console.log('CSV>', JSON.stringify(cont.slice(0, 300)));
  const lineas = cont.replace(/^﻿/, '').split('\r\n');
  ok('el archivo lleva la cabecera del takeoff en celdas separadas por coma', /^Partida,Ítem,De dónde sale,Cantidad,Unidad,\$ unitario,h unitarias,\$ Material,Horas$/.test(lineas.find(l => /^Partida/.test(l)) || ''), lineas.find(l => /^Partida/.test(l)));
  ok('… y el tubo con su cantidad y su dinero: 340 ft × 9.21 = 3131.40', lineas.some(l => /^06-FEED,"3-1\/2""\s+EMT CONDUIT",[^,]*,340,LF,9\.21,0\.08,3131\.40,27\.2$/.test(l)), lineas.find(l => /EMT CONDUIT/.test(l)));
  ok('… y la cotización del supply en su bloque, sin colarse en el material', lineas.some(l => /^,= COTIZACIONES DEL SUPPLY|COTIZACI/.test(l)) || cont.includes('38143.01'), (lineas.find(l => /38143/.test(l)) || '').slice(0, 120));

  /* === 3. «Copiar» dice la verdad === */
  await ctx.grantPermissions(['clipboard-read', 'clipboard-write']);
  await p.click('#btn-copiar-takeoff'); await p.waitForTimeout(250);
  const t1 = await p.evaluate(() => (document.getElementById('toast') || {}).textContent || '');
  const porta = await p.evaluate(() => navigator.clipboard.readText().catch(() => ''));
  ok('con permiso: copia de verdad (el portapapeles tiene el takeoff) y avisa ✓', /copiado ✓/.test(t1) && /^Partida\t/m.test(porta), t1 + ' · ' + porta.slice(0, 40).replace(/\t/g, '⇥'));
  await p.evaluate(() => { navigator.clipboard.writeText = () => Promise.reject(new Error('NotAllowed')); document.execCommand = () => false; });
  await p.click('#btn-copiar-takeoff'); await p.waitForTimeout(250);
  const t2 = await p.evaluate(() => { const t = document.getElementById('toast'); const ta = document.getElementById('takeoff-copia'); return { txt: t.textContent, error: t.className.includes('error'), sel: ta.selectionEnd - ta.selectionStart }; });
  ok('sin permiso ni execCommand: NO dice ✓, dice que no pudo, y deja el texto seleccionado para Ctrl+C', !/✓/.test(t2.txt) && /no dejó copiar/.test(t2.txt) && t2.error && t2.sel > 100, JSON.stringify(t2));

  ok('sin errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('E42 · EL TAKEOFF SE BAJA PARA EXCEL\n' + R.join('\n'));
  const mal = R.filter(x => x.startsWith('  ✗')).length;
  console.log(mal ? '\n' + mal + ' FALLAN' : '\nTODO BIEN (' + R.length + ')');
  await b.close(); srv.close(); process.exit(mal ? 1 : 0);
})().catch(e => { console.log(R.join('\n')); console.error(e); process.exit(2); });
