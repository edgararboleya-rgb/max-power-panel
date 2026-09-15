/* E14 · El takeoff pegado, pies contra MLF (15/09).
   El catálogo vende el THHN por MIL pies (MLF). Una fila del takeoff que casa
   por NOMBRE (sin alias) entraba con factor 1: 500 ft de 4/0 → 500 MLF, medio
   millón de pies. Aquí se comprueba que pies ÷ 1000 cuando el ítem es MLF, que
   piezas y LF no se tocan, y que el alias sigue mandando con su factor.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e14.js          */
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
/* nombres tal cual los tiene Edgar, con sus espacios de más */
const CAT = [
  { id: 1, item: '# 4/0   THHN STRANDED CU.', unidad: 'MLF', precio: 7663.33, orden: 101 },
  { id: 2, item: '# 12      THHN STRANDED CU.', unidad: 'MLF', precio: 220.94, orden: 102 },
  { id: 3, item: '2-1/2"  EMT CONDUIT', unidad: 'LF', precio: 4.2, orden: 103 },
  { id: 4, item: 'JB 1900 BOX', unidad: 'E', precio: 1.5, orden: 104 },
  { id: 5, item: '12/2   ROMEX', unidad: 'MLF', precio: 180, orden: 105 }
];
const ALIAS = [{ alias: '#12 THHN CU', item: '# 12      THHN STRANDED CU.', factor: 0.001 }];

(async () => {
  await new Promise(r => srv.listen(8867, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8867/index.html'); await p.waitForTimeout(500);
  await p.evaluate(([cat, alias]) => window.MXP_PRUEBA.e14.datos({ catalogo: cat, alias }), [CAT, ALIAS]);

  /* --- el CSV de MXP Planos / Bluebeam: Length en pies --- */
  const csv = [
    'Subject,Count,Length,Unit,Item Code',
    '# 4/0 THHN STRANDED CU.,,500,FT,',
    '2-1/2" EMT CONDUIT,,100,FT,',
    'JB 1900 BOX,3,,EA,',
    '#12 THHN CU,,275,FT,',
    '12/2 ROMEX,,55,,'
  ].join('\n');
  const filas = await p.evaluate(t => window.MXP_PRUEBA.e14.analiza(t).map(f => ({ ...f, m: window.MXP_PRUEBA.e14.empareja(f) })), csv);
  const de = s => filas.find(f => f.subject === s) || {};
  const cant = f => f.m ? Math.round(f.qty * f.m.factor * 1000) / 1000 : null;
  ok('el analizador marca como PIES lo que vino de Length o con Unit FT', de('# 4/0 THHN STRANDED CU.').lineal === true && de('2-1/2" EMT CONDUIT').lineal === true && de('JB 1900 BOX').lineal === false, JSON.stringify(filas.map(f => f.subject + ':' + f.lineal)));
  ok('500 ft de 4/0 casan por NOMBRE con el catálogo (espacios de más incluidos)', de('# 4/0 THHN STRANDED CU.').m && de('# 4/0 THHN STRANDED CU.').m.via === 'nombre', JSON.stringify(de('# 4/0 THHN STRANDED CU.').m));
  ok('… y entran como 0,5 MLF, no 500', cant(de('# 4/0 THHN STRANDED CU.')) === 0.5, 'cantidad=' + cant(de('# 4/0 THHN STRANDED CU.')) + ' → $' + Math.round(0.5 * 7663.33));
  ok('100 ft de EMT (catálogo en LF) entran como 100, sin tocar', cant(de('2-1/2" EMT CONDUIT')) === 100, 'cantidad=' + cant(de('2-1/2" EMT CONDUIT')));
  ok('3 cajas (E) entran como 3', cant(de('JB 1900 BOX')) === 3, 'cantidad=' + cant(de('JB 1900 BOX')));
  ok('el alias sigue mandando con SU factor: 275 ft de #12 → 0,275 MLF por alias', de('#12 THHN CU').m && de('#12 THHN CU').m.via === 'alias' && cant(de('#12 THHN CU')) === 0.275, JSON.stringify(de('#12 THHN CU').m));
  ok('Romex medido en Length sin columna Unit: también son pies → 0,055 MLF', cant(de('12/2 ROMEX')) === 0.055, 'cantidad=' + cant(de('12/2 ROMEX')));

  /* --- la misma fila por Count (piezas) contra un MLF NO se divide: no vino en pies --- */
  const porCount = await p.evaluate(() => { const f = window.MXP_PRUEBA.e14.analiza('Subject,Count\n# 4/0 THHN STRANDED CU.,2')[0]; return { lineal: f.lineal, factor: window.MXP_PRUEBA.e14.empareja(f).factor }; });
  ok('una cantidad que vino por Count (no por Length) no se divide aunque el ítem sea MLF: 2 quedan 2', porCount.lineal === false && porCount.factor === 1, JSON.stringify(porCount));

  /* --- por código de ítem también --- */
  const porCodigo = await p.evaluate(() => { const f = window.MXP_PRUEBA.e14.analiza('Subject,Length,Item Code\nlo que sea,1000,101')[0]; return window.MXP_PRUEBA.e14.empareja(f); });
  ok('casado por código (orden 101) en pies contra MLF: factor 0,001', porCodigo && porCodigo.via === 'código' && porCodigo.factor === 0.001, JSON.stringify(porCodigo));

  /* --- el factor puro --- */
  const puro = await p.evaluate(() => [
    window.MXP_PRUEBA.e14.factor({ lineal: true }, { unidad: 'MLF' }),
    window.MXP_PRUEBA.e14.factor({ lineal: false, unidad: 'LF' }, { unidad: 'MLF' }),
    window.MXP_PRUEBA.e14.factor({ lineal: true }, { unidad: 'LF' }),
    window.MXP_PRUEBA.e14.factor({ lineal: true }, { unidad: 'E' }),
    window.MXP_PRUEBA.e14.factor({}, { unidad: 'MLF' })
  ]);
  ok('factor: pies→MLF 0,001 (por Length o por Unit LF); pies→LF 1; pies→E 1; sin saber si son pies, 1', puro.join(',') === '0.001,0.001,1,1,1', puro.join(','));

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(x => x.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' pasos bien, todo bien'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
