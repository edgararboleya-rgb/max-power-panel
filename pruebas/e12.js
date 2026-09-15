/* E12 · Importar precios — la cotización del supply.
   Lo que hay que demostrar: que NADA se escribe sin aprobarlo, que lo que no
   casa seguro sale aparte en vez de colarse, que un "$1,234.00" se lee bien,
   y que una base comprada acaba en la columna de referencia y no en la tuya.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e12.js            */
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

const CAT = [
  { id: 1, item: '20A DUPLEX RECEPTACLE', seccion: 'WIRING DEVICES', precio: 3.40, horas_unidad: 0.30, orden: 101 },
  { id: 2, item: '1/2" EMT CONDUIT',      seccion: 'RACEWAY',        precio: 0.62, horas_unidad: 0.04, orden: 205 },
  { id: 3, item: 'JB 1900 BOX',           seccion: 'RACEWAY',        precio: 1.85, horas_unidad: 0.12, orden: 210 },
  { id: 4, item: '400A SWITCHGEAR',       seccion: 'SWITCHGEAR',     precio: 0,    horas_unidad: 14,   cero_motivo: 'suministro', orden: 300 },
  { id: 5, item: 'PANEL 100A MLO',        seccion: 'SWITCHGEAR',     precio: 210,  horas_unidad: 3, precio_ref: 260, fuente_ref: 'RSMeans 2026', orden: 310 }
];
const ALIAS = [{ alias: 'DUPLEX OUTLET 20A', item: '20A DUPLEX RECEPTACLE', factor: 1 }];

(async () => {
  await new Promise(r => srv.listen(8863, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8863/index.html'); await p.waitForTimeout(1200);
  await p.evaluate(d => window.MXP_PRUEBA.e12.datos(d), { catalogo: CAT, alias: ALIAS, config: {}, estimados: [] });

  /* === 1. leer un CSV de verdad === */
  const filas = await p.evaluate(() => window.MXP_PRUEBA.e12.csv('a,b\r\n"uno, con coma",2\r\n"dice ""hola""",3\r\n'));
  ok('el CSV se lee con comillas, comas dentro y CRLF', filas.length === 3 && filas[1][0] === 'uno, con coma' && filas[2][0] === 'dice "hola"', JSON.stringify(filas));
  /* Las PULGADAS: un CSV de supply trae 1/2" sin entrecomillar la celda. Si
     esa comilla se toma por apertura, se traga el resto del archivo. */
  const pulg = await p.evaluate(() => window.MXP_PRUEBA.e12.csv('Item,Price\n1/2" EMT CONDUIT,0.81\n3/4" EMT CONDUIT,1.20\n'));
  ok('una comilla de PULGADAS en medio del campo no se traga el archivo',
    pulg.length === 3 && pulg[1][0] === '1/2" EMT CONDUIT' && pulg[1][1] === '0.81' && pulg[2][0] === '3/4" EMT CONDUIT', JSON.stringify(pulg));
  const nums = await p.evaluate(() => ['$1,234.00', '12.50', '1.234,56', '(8.00)', '', 'n/a', '0'].map(v => window.MXP_PRUEBA.e12.num(v)));
  ok('los precios se leen como los escribe un proveedor', JSON.stringify(nums) === JSON.stringify([1234, 12.5, 1234.56, -8, null, null, 0]), JSON.stringify(nums));
  ok('y "vacío" NO es lo mismo que cero', nums[4] === null && nums[6] === 0);

  /* === 2. la propuesta del supply === */
  const CSV = [
    'Description,Unit,Net Price,Hours',
    '20A DUPLEX RECEPTACLE,E,"$4.10",0.30',
    'DUPLEX OUTLET 20A,E,"$4.10",',
    '1/2" EMT CONDUIT,FT,0.81,',
    'JB 1900 BOX,E,1.85,',
    '400A SWITCHGEAR,E,"$18,400.00",',
    'THINGAMAJIG XYZZY,E,9.99,',
    'ITEM SIN PRECIO,E,,',
    ''
  ].join('\r\n');
  const prop = await p.evaluate(c => window.MXP_PRUEBA.e12.propone(c, 'tuyo', 'City Electric 15/09'), CSV);
  ok('encuentra las columnas aunque se llamen en inglés', !prop.err && prop.col.item === 0 && prop.col.precio === 2 && prop.col.horas === 3, JSON.stringify(prop.col));
  ok('casa por nombre exacto, por alias y deja fuera lo que no existe',
    prop.cambios.length === 5 && prop.sinPareja.length === 1 && prop.sinPareja[0].nombre === 'THINGAMAJIG XYZZY', JSON.stringify({ c: prop.cambios.length, s: prop.sinPareja.length }));
  ok('el alias se reconoce y dice por dónde casó', (prop.cambios.find(c => c.via === 'alias') || {}).nombre === 'DUPLEX OUTLET 20A', JSON.stringify(prop.cambios.map(c => [c.nombre, c.via])));
  ok('el mismo item dos veces en el CSV se marca como repetido, no se suma', prop.cambios.filter(c => c.repetido).length === 1, JSON.stringify(prop.cambios.map(c => c.repetido)));
  ok('una fila sin precio ni horas se aparta en vez de poner cero', prop.sinNumero.length === 1 && prop.sinNumero[0].nombre === 'ITEM SIN PRECIO', JSON.stringify(prop.sinNumero));
  const emt = prop.cambios.find(c => /EMT/.test(c.nombre));
  ok('se enseña el precio de antes y el de ahora, y cuánto sube (0,62 → 0,81 = +31 %)',
    emt.antesP === 0.62 && emt.nuevoP === 0.81 && Math.abs(emt.dif - 0.3064516) < 1e-6 && emt.subeMucho === true, JSON.stringify({ a: emt.antesP, n: emt.nuevoP, d: emt.dif }));
  const jb = prop.cambios.find(c => /1900/.test(c.nombre));
  ok('lo que llega igual se marca como igual (no es un cambio)', jb.igual === true, JSON.stringify({ a: jb.antesP, n: jb.nuevoP, igual: jb.igual }));
  const sw = prop.cambios.find(c => /SWITCHGEAR/.test(c.nombre));
  ok('un item que estaba a $0 sale como NUEVO precio, no como subida rara (nada de +∞ %)',
    sw.antesP === 0 && sw.nuevoP === 18400 && sw.dif === null, JSON.stringify({ a: sw.antesP, n: sw.nuevoP, d: sw.dif }));
  ok('y se cuenta cuántos mueven de verdad', prop.mueven === 4 && prop.nuevos === 1, JSON.stringify({ m: prop.mueven, n: prop.nuevos }));
  /* El switchgear está a $0 A PROPÓSITO (E0: lo cotiza el supply por obra).
     Ponerle precio fijo cambia cómo se cotiza: eso se avisa, no se bloquea. */
  ok('un $0 puesto a propósito (por suministro) se marca antes de pisarlo',
    sw.eraCero === true && sw.ceroMotivo === 'suministro' && prop.ceros === 1, JSON.stringify({ e: sw.eraCero, m: sw.ceroMotivo, n: prop.ceros }));
  const noCero = prop.cambios.find(c => /EMT/.test(c.nombre));
  ok('y un precio normal que sube no lleva ese aviso', noCero.eraCero === false, JSON.stringify(noCero.eraCero));

  /* === 3. NADA se escribe sin aprobarlo === */
  const todos = await p.evaluate(pr => window.MXP_PRUEBA.e12.cambios(pr), prop);
  ok('proponer no escribe nada: solo devuelve qué habría que cambiar', Array.isArray(todos) && todos.every(x => x.id && x.campos), JSON.stringify(todos.map(x => x.item)));
  ok('lo que llega igual no genera escritura', !todos.some(x => /1900/.test(x.item)), JSON.stringify(todos.map(x => x.item)));
  const soloUno = await p.evaluate(pr => {
    const m = {}; pr.cambios.forEach((c, i) => { m[i] = /EMT/.test(c.nombre); });
    return window.MXP_PRUEBA.e12.cambios(pr, m);
  }, prop);
  ok('se puede aprobar fila a fila: marcando una, se escribe una', soloUno.length === 1 && /EMT/.test(soloUno[0].item), JSON.stringify(soloUno));
  ok('a lo tuyo va precio, horas, la fecha y de dónde salió',
    'precio' in todos[0].campos && 'precio_fecha' in todos[0].campos && todos[0].campos.precio_fuente === 'City Electric 15/09', JSON.stringify(todos[0].campos));

  /* === 4. una base comprada NO puede acabar en tu precio === */
  const ref = await p.evaluate(c => window.MXP_PRUEBA.e12.propone(c, 'referencia', 'RSMeans 2026'), CSV);
  const refCambios = await p.evaluate(pr => window.MXP_PRUEBA.e12.cambios(pr), ref);
  ok('con destino referencia se escribe precio_ref, NUNCA precio',
    refCambios.every(x => 'precio_ref' in x.campos && !('precio' in x.campos) && x.campos.fuente_ref === 'RSMeans 2026'), JSON.stringify(refCambios[0].campos));
  ok('y la referencia se compara contra la referencia de antes, no contra tu precio',
    ref.cambios.find(c => /EMT/.test(c.nombre)).antesP === null, JSON.stringify(ref.cambios.find(c => /EMT/.test(c.nombre))));

  /* === 5. tuyo vs referencia === */
  const vs = await p.evaluate(c => window.MXP_PRUEBA.e12.vs(c), CAT);
  ok('«tuyo vs referencia» solo mira los que tienen las dos cosas', vs.length === 1 && vs[0].item === 'PANEL 100A MLO', JSON.stringify(vs));
  ok('y dice cuánto te separas (210 contra 260 = −19 %)', Math.abs(vs[0].dif + 0.1923077) < 1e-6, vs[0].dif.toFixed(4));
  const vsTodo = await p.evaluate(c => window.MXP_PRUEBA.e12.vs(c, 0.5), CAT);
  ok('con un límite más alto, ese ya no salta', vsTodo.length === 0, JSON.stringify(vsTodo));

  /* === 6. archivos que no valen === */
  const malo1 = await p.evaluate(() => window.MXP_PRUEBA.e12.propone('hola mundo\n', 'tuyo', ''));
  ok('un archivo de una sola línea se rechaza: eso no trae datos', !!malo1.err && /no trae filas/.test(malo1.err), (malo1.err || '').slice(0, 70));
  const malo2 = await p.evaluate(() => window.MXP_PRUEBA.e12.propone('', 'tuyo', ''));
  ok('un archivo vacío se rechaza sin romperse', !!malo2.err, (malo2.err || '').slice(0, 60));
  const malo3 = await p.evaluate(() => window.MXP_PRUEBA.e12.propone('Item,Notas\nALGO,hola\n', 'tuyo', ''));
  ok('sin columna de precio ni de horas, tampoco se inventa nada', !!malo3.err && /precio ni horas/.test(malo3.err), (malo3.err || '').slice(0, 70));
  const neg = await p.evaluate(() => window.MXP_PRUEBA.e12.propone('Item,Price\n20A DUPLEX RECEPTACLE,-5\n', 'tuyo', ''));
  ok('un precio negativo no entra al catálogo', neg.cambios.length === 0 && neg.sinNumero.length === 1, JSON.stringify(neg.sinNumero));

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(x => x.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' ok'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
