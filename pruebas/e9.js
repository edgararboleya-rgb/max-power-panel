/* E9 · Las recetas (ensambles) por dentro, y el escalado por pies medidos.
   Lo que se comprueba, por este orden:
     1. que una receta de las de HOY dé exactamente lo mismo que antes, y
     2. que medir los pies ya no pierda cable ni tubo.
   Dos fugas encontradas el 16/09 al preparar E9:
     · el conductor se sustituía por `pies/1000`, así que en una receta de
       3 hilos (0.075 MLF = 75 ft para 25 ft de corrida) medir 25 ft dejaba
       0.025: UN TERCIO del cable, en silencio;
     · el tubo no se tocaba: 50 ft medidos seguían comprando 25 LF de EMT.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e9.js          */
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
/* catálogo de mentira con los nombres raros de Edgar (espacios dobles incluidos) */
const CAT = [
  { id: 1, item: '20A DUPLEX  RECEPTACLE', seccion: 'WIRING DEVICES', unidad: 'E', precio: 1.44, horas_unidad: 0.4 },
  { id: 2, item: '4-11/16 BOX', seccion: 'RACEWAY', unidad: 'E', precio: 6.75, horas_unidad: 0.35 },
  { id: 3, item: '1  GANG PLASTER RING 1/2"', seccion: 'RACEWAY', unidad: 'E', precio: 0.357, horas_unidad: 0.05 },
  { id: 4, item: '1/2"     EMT CONDUIT', seccion: 'RACEWAY', unidad: 'LF', precio: 0.525, horas_unidad: 0.03 },
  { id: 5, item: '# 12      THHN STRANDED CU.', seccion: 'WIRING', unidad: 'MLF', precio: 220.94, horas_unidad: 6 },
  { id: 6, item: '1/2"       EMT S.S. D/C CONNECTOR', seccion: 'RACEWAY', unidad: 'E', precio: 0.266, horas_unidad: 0.06 },
  { id: 7, item: '1/2"       EMT S.S. D/C COUPLING', seccion: 'RACEWAY', unidad: 'E', precio: 0.306, horas_unidad: 0.04 },
  { id: 8, item: '1/2"      EMT STRAP 1 HOLE STRAP', seccion: 'RACEWAY', unidad: 'E', precio: 0.0682, horas_unidad: 0.02 },
  { id: 9, item: '12/2   ROMEX', seccion: 'WIRING', unidad: 'MLF', precio: 180, horas_unidad: 22 },
  { id: 10, item: 'NM STAPLE', seccion: 'RACEWAY', unidad: 'E', precio: 0.06, horas_unidad: 0.01 },
  { id: 11, item: '1 GANG PLASTIC BOX', seccion: 'RACEWAY', unidad: 'E', precio: 0.55, horas_unidad: 0.2 },
  { id: 12, item: 'YELLOW WIRENUTS', seccion: 'MISCELLANEOUS', unidad: 'E', precio: 0.26, horas_unidad: 0.01 },
];
/* dos recetas: una en EMT con 3 hilos (25 ft de corrida) y una Romex de las de hoy */
const ENS = [
  { id: 100, nombre: 'RECEPTÁCULO 20A — EMT', modo: 'comercial', pies_editable: true, orden: 1 },
  { id: 200, nombre: 'NEW OUTLET (EXISTING CIRCUIT)', modo: 'remodelacion', pies_editable: true, orden: 2 },
];
const EI = [
  { id: 1, ensamble_id: 100, item: '20A DUPLEX  RECEPTACLE', cantidad: 1 },
  { id: 2, ensamble_id: 100, item: '4-11/16 BOX', cantidad: 1 },
  { id: 3, ensamble_id: 100, item: '1  GANG PLASTER RING 1/2"', cantidad: 1 },
  { id: 4, ensamble_id: 100, item: '1/2"     EMT CONDUIT', cantidad: 25 },
  { id: 5, ensamble_id: 100, item: '# 12      THHN STRANDED CU.', cantidad: 0.075 },
  { id: 6, ensamble_id: 100, item: '1/2"       EMT S.S. D/C CONNECTOR', cantidad: 2 },
  { id: 7, ensamble_id: 100, item: '1/2"       EMT S.S. D/C COUPLING', cantidad: 2.5 },
  { id: 8, ensamble_id: 100, item: '1/2"      EMT STRAP 1 HOLE STRAP', cantidad: 3 },
  { id: 9, ensamble_id: 100, item: 'YELLOW WIRENUTS', cantidad: 3 },
  { id: 10, ensamble_id: 200, item: '20A DUPLEX  RECEPTACLE', cantidad: 1 },
  { id: 11, ensamble_id: 200, item: '1 GANG PLASTIC BOX', cantidad: 1 },
  { id: 12, ensamble_id: 200, item: '12/2   ROMEX', cantidad: 0.025 },
  { id: 13, ensamble_id: 200, item: 'NM STAPLE', cantidad: 4 },
  { id: 14, ensamble_id: 200, item: 'YELLOW WIRENUTS', cantidad: 3 },
];
const r3 = v => Math.round(v * 1000) / 1000;

(async () => {
  await new Promise(r => srv.listen(8869, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1200, height: 800 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8869/index.html'); await p.waitForTimeout(500);
  await p.evaluate(([cat, ens, ei]) => window.MXP_PRUEBA.e9.datos({ catalogo: cat, ensambles: ens, ensambleItems: ei }), [CAT, ENS, EI]);

  /* --- la receta tal cual, sin medir pies --- */
  const base = await p.evaluate(() => window.MXP_PRUEBA.e9.explota(100, 1));
  const de = (arr, n) => (arr.find(x => x.item === n) || {});
  ok('una receta en EMT explota en sus 9 componentes con precio y horas del catálogo',
    base.length === 9 && de(base, '20A DUPLEX  RECEPTACLE').precio === 1.44 && de(base, '# 12      THHN STRANDED CU.').horas === 6,
    base.length + ' componentes');
  ok('el nombre con espacios dobles casa con el catálogo (si no, entraría a $0 y 0 h)',
    base.every(c => c.precio > 0 || /WIRENUT/.test(c.item)), base.filter(c => !c.precio).map(c => c.item).join(' | ') || 'todos con precio');
  /* LA VARA, bien puesta: en el Excel de Edgar el PUNTO (dispositivo + caja +
     tapa) son 0,63 h y el cable y el tubo van en su propia línea con sus
     horas (MC 28 h/MLF, EMT ½" 0,03 h/ft, THHN 6 h/MLF). Una receta que
     incluye la corrida tiene que dar la suma de las dos cosas: en Stuart,
     3.000 ft de MC 12/2 entre ~61 puntos son 1,4 h de cable por punto. */
  const desglose = await p.evaluate(() => {
    const b = window.MXP_PRUEBA.e9.explota(100, 1);
    const esCorrida = c => /CONDUIT|THHN|ROMEX|MC\b|STRAP|COUPLING|CONNECTOR/.test(c.item);
    const h = f => b.filter(f).reduce((s, c) => s + c.horas * c.cantidad, 0);
    return { punto: h(c => !esCorrida(c)), corrida: h(esCorrida), total: h(() => true) };
  });
  ok('el PUNTO de la receta (receptáculo + caja + anillo + wirenuts) da 0,8 h, la vara de Edgar es 0,63',
    Math.abs(desglose.punto - 0.63) < 0.25, desglose.punto.toFixed(2) + ' h');
  ok('y la CORRIDA (25 ft de tubo + 75 ft de hilo + accesorios) pone el resto: total ~2,3 h por punto terminado en EMT',
    desglose.corrida > 1.2 && desglose.total > 2 && desglose.total < 2.8,
    'punto ' + desglose.punto.toFixed(2) + ' + corrida ' + desglose.corrida.toFixed(2) + ' = ' + desglose.total.toFixed(2) + ' h');

  /* --- los pies de CORRIDA son los del tubo, no los del cable --- */
  const corrida = await p.evaluate(() => ({ emt: window.MXP_PRUEBA.e9.piesCorrida(100), romex: window.MXP_PRUEBA.e9.piesCorrida(200) }));
  ok('la corrida de la receta EMT son 25 ft (el tubo), no 75 (los tres hilos)', corrida.emt === 25, 'EMT=' + corrida.emt);
  ok('en Romex, donde no hay tubo, la corrida la marca el cable: 25 ft', corrida.romex === 25, 'Romex=' + corrida.romex);

  /* --- medir el doble de pies compra el doble de todo lo lineal --- */
  const doble = await p.evaluate(() => window.MXP_PRUEBA.e9.explota(100, 1, 50));
  ok('con 50 ft medidos el CABLE se dobla con sus tres hilos: 0,075 → 0,15 MLF (antes daba 0,05 y se perdía un tercio)',
    r3(de(doble, '# 12      THHN STRANDED CU.').cantidad) === 0.15, de(doble, '# 12      THHN STRANDED CU.').cantidad);
  ok('y el TUBO se dobla: 25 → 50 LF (antes se quedaba en 25 y el bid no lo cobraba)',
    de(doble, '1/2"     EMT CONDUIT').cantidad === 50, de(doble, '1/2"     EMT CONDUIT').cantidad);
  ok('los acoples y las grapas crecen con la corrida, redondeando arriba: 2,5 → 5 acoples, 3 → 6 straps',
    de(doble, '1/2"       EMT S.S. D/C COUPLING').cantidad === 5 && de(doble, '1/2"      EMT STRAP 1 HOLE STRAP').cantidad === 6,
    JSON.stringify({ acoples: de(doble, '1/2"       EMT S.S. D/C COUPLING').cantidad, straps: de(doble, '1/2"      EMT STRAP 1 HOLE STRAP').cantidad }));
  ok('los conectores NO crecen: son dos por salida, mida lo que mida la corrida',
    de(doble, '1/2"       EMT S.S. D/C CONNECTOR').cantidad === 2, de(doble, '1/2"       EMT S.S. D/C CONNECTOR').cantidad);
  ok('el receptáculo, la caja y el anillo tampoco: uno por punto',
    de(doble, '20A DUPLEX  RECEPTACLE').cantidad === 1 && de(doble, '4-11/16 BOX').cantidad === 1 && de(doble, '1  GANG PLASTER RING 1/2"').cantidad === 1);

  /* --- la receta Romex de HOY no se mueve ni un centavo --- */
  const rx25 = await p.evaluate(() => window.MXP_PRUEBA.e9.explota(200, 1, 25));
  const rx50 = await p.evaluate(() => window.MXP_PRUEBA.e9.explota(200, 1, 50));
  ok('Romex con 25 ft medidos = la receta tal cual: 0,025 MLF (lo mismo que daba antes del arreglo)',
    r3(de(rx25, '12/2   ROMEX').cantidad) === 0.025, de(rx25, '12/2   ROMEX').cantidad);
  ok('Romex con 50 ft medidos: 0,05 MLF y 8 grapas (antes también daba 0,05: no se mueve nada)',
    r3(de(rx50, '12/2   ROMEX').cantidad) === 0.05 && de(rx50, 'NM STAPLE').cantidad === 8,
    JSON.stringify({ cable: de(rx50, '12/2   ROMEX').cantidad, grapas: de(rx50, 'NM STAPLE').cantidad }));

  /* --- varias unidades y pies a la vez --- */
  const diez = await p.evaluate(() => window.MXP_PRUEBA.e9.explota(100, 10, 40));
  ok('10 puntos de 40 ft: 400 LF de tubo, 1,2 MLF de cable y 10 receptáculos',
    de(diez, '1/2"     EMT CONDUIT').cantidad === 400 && r3(de(diez, '# 12      THHN STRANDED CU.').cantidad) === 1.2 && de(diez, '20A DUPLEX  RECEPTACLE').cantidad === 10,
    JSON.stringify({ tubo: de(diez, '1/2"     EMT CONDUIT').cantidad, cable: r3(de(diez, '# 12      THHN STRANDED CU.').cantidad) }));

  /* --- lo que cuesta la fuga, en dinero de verdad --- */
  const fuga = await p.evaluate(() => {
    const antes = window.MXP_PRUEBA.e9.explota(100, 30);          // 30 puntos con la receta de 25 ft
    const real = window.MXP_PRUEBA.e9.explota(100, 30, 45);       // los mismos 30, medidos a 45 ft
    const $ = a => a.reduce((s, c) => s + c.precio * c.cantidad, 0);
    const h = a => a.reduce((s, c) => s + c.horas * c.cantidad, 0);
    return { antes: Math.round($(antes)), real: Math.round($(real)), hAntes: Math.round(h(antes)), hReal: Math.round(h(real)) };
  });
  ok('medir de verdad cambia el número: 30 puntos a 45 ft cuestan más material y más horas que la receta de 25 ft',
    fuga.real > fuga.antes && fuga.hReal > fuga.hAntes, JSON.stringify(fuga));

  /* --- un componente con el nombre mal escrito se ve: entra a $0 --- */
  const malo = await p.evaluate(() => {
    window.MXP_PRUEBA.e9.datos({ catalogo: [{ id: 1, item: '20A DUPLEX  RECEPTACLE', unidad: 'E', precio: 1.44, horas_unidad: 0.4 }],
      ensambles: [{ id: 300, nombre: 'MALA', modo: 'comercial', pies_editable: false }],
      ensambleItems: [{ id: 1, ensamble_id: 300, item: '20A DUPLEX RECEPTACLE' }, { id: 2, ensamble_id: 300, item: 'CAJA QUE NO EXISTE', cantidad: 1 }] });
    return window.MXP_PRUEBA.e9.explota(300, 1);
  });
  ok('un componente que no está en el catálogo entra a $0 y 0 h (por eso el SQL de E9 se valida antes)',
    malo.some(c => c.item === 'CAJA QUE NO EXISTE' && !c.precio && !c.horas), JSON.stringify(malo.map(c => c.item + ':' + c.precio)));
  ok('en cambio el nombre con UN espacio en vez de dos SÍ casa (la app normaliza espacios)',
    (malo.find(c => c.item === '20A DUPLEX RECEPTACLE') || {}).precio === 1.44, JSON.stringify((malo.find(c => c.item === '20A DUPLEX RECEPTACLE') || {})));

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(x => x.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' pasos bien, todo bien'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
