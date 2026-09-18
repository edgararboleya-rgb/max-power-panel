/* E25 · CONSUMIBLES AUTOMÁTICOS POR REGLAS.
   Edgar, 17/09: «cuando yo te dé 12.000 pies de cable y 30 cajas, esas cajas
   tienen que llevar sus fittings automáticos… eso es un conteo que yo no tengo
   que hacer. Y ahora mismo automático nada más me salían como tres renglones».
   El fixture es el trabajo REAL de Nicklaus: 6.039 ft de 1/2", 440 ft de 1",
   27.774 ft de #12, 284 cajas, y las recetas que ya traen sus propios acoples,
   conectores y grapas — que es donde estaba el peligro de cobrarlo dos veces.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e25.js            */
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

/* El catálogo, con los nombres TAL CUAL los tiene Edgar — espacios raros y la
   errata «STARP» incluidas: es justo lo que rompía la búsqueda vieja. */
const CAT = [
  { item: '1/2"     EMT CONDUIT',              unidad: 'LF', precio: 0.6124, horas_unidad: 0.03,  codigo: '09-COND' },
  { item: '1"         EMT CONDUIT',            unidad: 'LF', precio: 1.8776, horas_unidad: 0.045, codigo: '09-COND' },
  { item: '1/2"       EMT S.S. D/C COUPLING',  unidad: 'E',  precio: 0.4529, horas_unidad: 0.04,  codigo: '09-COND' },
  { item: '1"           EMT S.S.D/C  COUPLING',unidad: 'E',  precio: 0.8007, horas_unidad: 0.05,  codigo: '09-COND' },
  { item: '1/2"       EMT S.S. D/C CONNECTOR', unidad: 'E',  precio: 1.1679, horas_unidad: 0.06,  codigo: '09-COND' },
  { item: '1"           EMT S.S.D/C CONNECTOR',unidad: 'E',  precio: 0.5452, horas_unidad: 0.08,  codigo: '09-COND' },
  // (18/09) TAL CUAL su catálogo: el POWER STRAP y el anillo de concreto están
  // ANTES que la pieza buena, y con la búsqueda vieja ganaban ellos.
  { item: '1/2"  EMT POWER STRAP (2 HOLE)',    unidad: 'E',  precio: 0.30,   horas_unidad: 0.03,  codigo: '09-COND' },
  { item: '4" BLANK COVER CONCRETE RING',      unidad: 'E',  precio: 0.70,   horas_unidad: 0.06,  codigo: '09-COND' },
  { item: '1/2"      EMT STRAP 1 HOLE STRAP',  unidad: 'E',  precio: 0.1459, horas_unidad: 0.02,  codigo: '09-COND' },
  { item: '1"          EMT STRAP 1 HOLE STARP',unidad: 'E',  precio: 0.2087, horas_unidad: 0.025, codigo: '09-COND' },
  { item: 'TAPCON 1/4" x 1-1/4"',              unidad: 'E',  precio: 0.35,   horas_unidad: 0.01,  codigo: '09-COND' },
  { item: 'JB 1900 BOX',                       unidad: 'E',  precio: 1.04,   horas_unidad: 0.25,  codigo: '09-COND' },
  { item: 'JB 1900 DEEP BOX',                  unidad: 'E',  precio: 1.8261, horas_unidad: 0.25,  codigo: '09-COND' },
  { item: '4"X4" BLANK COVER',                 unidad: 'E',  precio: 0.804,  horas_unidad: 0.07,  codigo: '09-COND' },
  { item: '# 12      THHN STRANDED CU.',       unidad: 'MLF',precio: 272.6,  horas_unidad: 6,     codigo: '08-ROUGH' },
  // los que da de alta el e25
  { item: '1/2"  EMT UNISTRUT STRAP',          unidad: 'E',  precio: 0.60,   horas_unidad: 0.03,  codigo: '09-COND' },
  { item: 'UNISTRUT 1-5/8" P1000',             unidad: 'LF', precio: 4.50,   horas_unidad: 0.05,  codigo: '09-COND' },
  { item: 'ALL-THREAD ROD 1/4"',               unidad: 'LF', precio: 0.85,   horas_unidad: 0.03,  codigo: '09-COND' },
  { item: '1/4" HEX NUT',                      unidad: 'E',  precio: 0.06,   horas_unidad: 0.01,  codigo: '09-COND' },
  { item: '1/4" FLAT WASHER',                  unidad: 'E',  precio: 0.05,   horas_unidad: 0.01,  codigo: '09-COND' },
  { item: '1/4" CONCRETE ANCHOR (DROP-IN)',    unidad: 'E',  precio: 0.55,   horas_unidad: 0.08,  codigo: '09-COND' },
  { item: 'ELECTRICAL TAPE 3/4" x 66FT',       unidad: 'E',  precio: 1.50,   horas_unidad: 0,     codigo: '20-MISC' },
  { item: 'WIRE PULLING LUBRICANT 1 QT',       unidad: 'E',  precio: 9.00,   horas_unidad: 0,     codigo: '20-MISC' },
  { item: 'WIRE MARKER BOOK',                  unidad: 'E',  precio: 12.00,  horas_unidad: 0,     codigo: '20-MISC' }
];
const it = (item, cantidad, unidad, deEnsamble) => ({ item, cantidad, unidad, precio: 0, horas: 0, deEnsamble });
/* El trabajo: el tubo y el cable que Edgar midió en Bluebeam, las cajas
   contadas, y lo que las recetas ya traen puesto. */
const NICKLAUS = [
  it('1/2"     EMT CONDUIT', 6039, 'LF'),
  it('1"         EMT CONDUIT', 440, 'LF'),
  it('# 12      THHN STRANDED CU.', 27.774, 'MLF'),
  it('JB 1900 DEEP BOX', 206, 'E', 'RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT'),
  it('JB 1900 BOX', 76, 'E', 'LUMINARIA 2X2 — EMT'),
  it('1/2"       EMT S.S. D/C CONNECTOR', 486, 'E', 'RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT'),
  it('1"           EMT S.S.D/C CONNECTOR', 44, 'E', 'SALIDA DE DATOS — SOLO ROUGH'),
  it('1/2"       EMT S.S. D/C COUPLING', 406, 'E', 'RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT'),
  it('1/2"      EMT STRAP 1 HOLE STRAP', 586, 'E', 'RECEPTÁCULO 20A HOSPITAL GRADE TR — EMT')
];

(async () => {
  await new Promise(r => srv.listen(8866, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  await p.goto('http://localhost:8866/index.html'); await p.waitForTimeout(500);
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c }), CAT);
  const corre = (est, cfg) => p.evaluate(([base, est, cfg]) => {
    const r = window.MXP_PRUEBA.e0.consumibles(base, est, cfg);
    return { avisos: r.avisos, cubiertos: r.cubiertos, autos: r.autos.map(a => ({ item: a.item.replace(/\s+/g, ' ').trim(), q: a.cantidad, motivo: a.auto, ids: a.reglaIds || [] })) };
  }, [NICKLAUS, est, cfg || {}]);
  const q = (r, frag) => { const a = r.autos.find(x => x.item.includes(frag)); return a ? a.q : null; };

  /* === 0. (v191) cada renglón automático dice de QUÉ regla salió: es lo que
         deja enseñar, en la tabla editable, qué produjo cada número === */
  const conId = await corre({ soporte: 'pared' });
  ok('cada renglón automático lleva el id de su regla (para la tabla editable)',
    conId.autos.length > 0 && conId.autos.every(a => a.ids.length > 0), JSON.stringify(conId.autos.slice(0, 3).map(a => [a.item.slice(0, 18), a.ids])));
  ok('el acople lo firma la regla «coupling» y el tapcon la regla «tapcon»',
    (conId.autos.find(a => /COUPLING/.test(a.item)) || {}).ids.join() === 'coupling' &&
    (conId.autos.find(a => /TAPCON/.test(a.item)) || {}).ids.join() === 'tapcon',
    JSON.stringify(conId.autos.filter(a => /COUPLING|TAPCON/.test(a.item)).map(a => a.ids)));

  /* === 0b. (v193) el que MEJOR casa, no el primero que casa === */
  ok('la regla del one-hole coge el ONE HOLE, no el POWER STRAP que está antes en la lista',
    !!conId.autos.find(a => /STRAP 1 HOLE/.test(a.item)) && !conId.autos.find(a => /POWER STRAP/.test(a.item)),
    JSON.stringify(conId.autos.filter(a => /STRAP/.test(a.item)).map(a => a.item)));
  ok('la tapa ciega coge la tapa, no el anillo de concreto',
    !!conId.autos.find(a => /4"X4" BLANK COVER/.test(a.item)) && !conId.autos.find(a => /CONCRETE RING/.test(a.item)),
    JSON.stringify(conId.autos.filter(a => /BLANK|RING/.test(a.item)).map(a => a.item)));

  /* === 0c. (v196) una regla que acaba en 0 porque las recetas ya lo traían no
         puede verse igual que una que no corrió === */
  ok('lo que las recetas ya traen queda apuntado, aunque el renglón acabe en 0',
    conId.cubiertos && Object.keys(conId.cubiertos).length > 0, JSON.stringify(conId.cubiertos));

  /* === 1. pared o losa: lo normal === */
  const pared = await corre({ soporte: 'pared' });
  ok('acoples de 1/2": 10 por 100 ft de 6.039 ft = 604, menos los 406 que ya traen las recetas → 198',
    q(pared, '1/2" EMT S.S. D/C COUPLING') === 198, q(pared, '1/2" EMT S.S. D/C COUPLING'));
  ok('acoples de 1": 10 por 100 ft de 440 ft = 44, y las recetas no traían ninguno → 44',
    q(pared, '1" EMT S.S.D/C COUPLING') === 44, q(pared, '1" EMT S.S.D/C COUPLING'));
  ok('la búsqueda por palabras encuentra el acople aunque el catálogo diga «S.S. D/C» en medio (antes no lo encontraba y la regla no corría)',
    q(pared, '1/2" EMT S.S. D/C COUPLING') > 0 && q(pared, '1" EMT S.S.D/C COUPLING') > 0);
  ok('grapas de 1/2": 604 menos las 586 de las recetas → 18; y la de 1" (con su errata «STARP») sale igual: 44',
    q(pared, '1/2" EMT STRAP 1 HOLE STRAP') === 18 && q(pared, '1" EMT STRAP 1 HOLE STARP') === 44,
    q(pared, '1/2" EMT STRAP 1 HOLE STRAP') + ' / ' + q(pared, '1" EMT STRAP 1 HOLE STARP'));
  const conect = (q(pared, '1/2" EMT S.S. D/C CONNECTOR') || 0) + (q(pared, '1" EMT S.S.D/C CONNECTOR') || 0);
  ok('conectores: 2 por cada una de las 284 cajas = 568, y las recetas ya traían 530 → solo entran los que faltan',
    conect > 0 && conect < 100, 'faltan ' + conect);
  ok('tapcons: 2 por cada grapa que pide la regla (648 de las dos tallas) = 1.296',
    q(pared, 'TAPCON 1/4" x 1-1/4"') === 1296, q(pared, 'TAPCON 1/4" x 1-1/4"'));
  ok('cajas de paso: 1 por cada 100 ft de tubo = 65, menos las 76 que ya vienen en las recetas → ninguna',
    q(pared, 'JB 1900 BOX') === null, q(pared, 'JB 1900 BOX'));
  ok('tapas ciegas: 1 por cada 100 ft y ninguna venía en las recetas → 65',
    q(pared, '4"X4" BLANK COVER') === 65, q(pared, '4"X4" BLANK COVER'));
  ok('tape: 1 rollo por cada 500 ft de conductor (27.774 ft) → 56',
    q(pared, 'ELECTRICAL TAPE') === 56, q(pared, 'ELECTRICAL TAPE'));
  ok('grasa de alambrar: 1 cuarto por cada 1.000 ft → 28',
    q(pared, 'WIRE PULLING LUBRICANT') === 28, q(pared, 'WIRE PULLING LUBRICANT'));
  ok('libreta de números: 1 cada 5.000 ft → 6',
    q(pared, 'WIRE MARKER BOOK') === 6, q(pared, 'WIRE MARKER BOOK'));
  ok('ninguna regla se queda sin correr por falta de ítem en el catálogo', pared.avisos.length === 0, pared.avisos.join(' | '));
  ok('y cada renglón dice de qué regla salió, y cuánto venía ya en las recetas',
    /10 por 100 ft de 1\/2"/.test(pared.autos.find(a => /1\/2" EMT S.S. D\/C COUPLING/.test(a.item)).motivo) &&
    /ya venían 406/.test(pared.autos.find(a => /1\/2" EMT S.S. D\/C COUPLING/.test(a.item)).motivo),
    pared.autos.find(a => /1\/2" EMT S.S. D\/C COUPLING/.test(a.item)).motivo);
  ok('sin trapecio no entra ni unistrut, ni varilla, ni tuercas, ni anclas',
    !q(pared, 'UNISTRUT') && !q(pared, 'ALL-THREAD') && !q(pared, 'HEX NUT') && !q(pared, 'CONCRETE ANCHOR'));

  /* === 2. trapecio: el 30 % del tubo va colgado === */
  const rack = await corre({ soporte: 'unistrut', pct_rack: 0.3 });
  const ftRack = (6039 + 440) * 0.3, trap = ftRack / 8;
  ok('unistrut strap: 12 por 100 ft del tubo que va en rack (30 % de 6.039 ft de 1/2")',
    q(rack, '1/2" EMT UNISTRUT STRAP') === Math.ceil(6039 * 0.3 / 100 * 12), q(rack, '1/2" EMT UNISTRUT STRAP'));
  ok('un trapecio cada 8 ft del tubo en rack: ' + Math.round(trap) + ' trapecios → 2 ft de unistrut y 6 ft de varilla cada uno',
    q(rack, 'UNISTRUT 1-5/8') === Math.ceil(trap * 2) && q(rack, 'ALL-THREAD ROD') === Math.ceil(trap * 6),
    q(rack, 'UNISTRUT 1-5/8') + ' ft strut / ' + q(rack, 'ALL-THREAD ROD') + ' ft varilla');
  ok('y sus 4 tuercas, 4 arandelas y 2 anclas por trapecio',
    q(rack, 'HEX NUT') === Math.ceil(trap * 4) && q(rack, 'FLAT WASHER') === Math.ceil(trap * 4) && q(rack, 'CONCRETE ANCHOR') === Math.ceil(trap * 2),
    [q(rack, 'HEX NUT'), q(rack, 'FLAT WASHER'), q(rack, 'CONCRETE ANCHOR')].join(' / '));
  ok('con trapecio NO entran ni one-hole strap ni tapcons: esa fijación no es la de este trabajo',
    !q(rack, 'EMT STRAP 1 HOLE') && !q(rack, 'TAPCON'), [q(rack, 'EMT STRAP 1 HOLE'), q(rack, 'TAPCON')].join(' / '));
  ok('los acoples siguen saliendo igual, que no dependen de cómo vaya colgado',
    q(rack, '1/2" EMT S.S. D/C COUPLING') === 198, q(rack, '1/2" EMT S.S. D/C COUPLING'));

  /* === 3. Edgar corrige los números: la tabla es suya === */
  const mio = await corre({ soporte: 'pared' }, { consumibles: '{"coupling":12,"tapcon":3}' });
  ok('si Edgar pone 12 acoples por 100 ft, salen 12: 6.039 ft → 725 menos los 406 de las recetas = 319',
    q(mio, '1/2" EMT S.S. D/C COUPLING') === 319, q(mio, '1/2" EMT S.S. D/C COUPLING'));
  ok('y 3 tapcons por grapa en vez de 2 → 1.944', q(mio, 'TAPCON') === 1944, q(mio, 'TAPCON'));
  ok('la corrección se guarda como un JSON en config_estimador y lo demás no se mueve',
    q(mio, '4"X4" BLANK COVER') === 65, q(mio, '4"X4" BLANK COVER'));

  /* === 4. lo que el motor NO puede hacer se dice, no se calla === */
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c }), CAT.filter(x => !/UNISTRUT|ALL-THREAD|HEX NUT|WASHER|ANCHOR/.test(x.item)));
  const sinCat = await corre({ soporte: 'unistrut', pct_rack: 0.3 });
  /* (v195) y si la pieza buena no está pero sí una parecida que la regla
     descarta, el aviso la nombra: callarlo deja el trabajo sin grapas */
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c }), CAT.filter(x => !/STRAP 1 HOLE/.test(x.item)));
  const sinOneHole = await corre({ soporte: 'pared' });
  ok('sin one-hole en el catálogo, el aviso NOMBRA la pieza parecida que descartó y dice qué hacer',
    /One-hole strap/.test(sinOneHole.avisos.join(' ')) && /Lo más parecido es «[^»]*STRAP[^»]*»/.test(sinOneHole.avisos.join(' ')) && /cómo va sujeto/.test(sinOneHole.avisos.join(' ')),
    (sinOneHole.avisos.find(a => /One-hole/.test(a)) || '').slice(0, 170));
  await p.evaluate(c => window.MXP_PRUEBA.e0.datos({ catalogo: c }), CAT);

  ok('sin los ítems del trapecio en el catálogo, la regla no corre pero AVISA (antes se callaba)',
    sinCat.avisos.length >= 4 && /no encuentro/.test(sinCat.avisos[0]), sinCat.avisos.slice(0, 2).join(' | '));

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 200));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(r => r.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' pasos bien, todo bien'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
