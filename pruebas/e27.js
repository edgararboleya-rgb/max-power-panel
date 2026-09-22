/* E27 · PASO 7 — las HORAS que el estimador propone solo, el PRECIO DE
   REFERENCIA de las luminarias y la CUOTA del supply pegada tal cual.
   El fixture es Nicklaus: 47 breakers, 31 dimmers/sensores, 95 receptáculos,
   55 luminarias que pone otro, y las cinco líneas de «COTIZACIÓN PENDIENTE»
   con los modelos reales de Lithonia.
   Uso: NODE_PATH=/opt/node22/lib/node_modules node pruebas/e27.js            */
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

/* El catálogo: los nueve ítems de horas (e23d + e27) y lo que hace falta para
   que el estimado tenga sentido. */
const CAT = [
  { item: 'TERMINACIÓN DE CIRCUITO EN PANEL (por ckt)',                   unidad: 'E', precio: 0, horas_unidad: 0.50, codigo: '05-PANEL', cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: 'ROTULADO DE CIRCUITO Y DIRECTORIO DE PANEL (por ckt)',         unidad: 'E', precio: 0, horas_unidad: 0.10, codigo: '05-PANEL', cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: 'DEMOLICIÓN DE DISPOSITIVO O LUMINARIA EXISTENTE (por unidad)', unidad: 'E', precio: 0, horas_unidad: 0.35, codigo: '01-DEMO',  cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: 'PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)',          unidad: 'E', precio: 0, horas_unidad: 0.25, codigo: '11-LIGHT', cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: 'AS-BUILT, PRUEBAS Y CIERRE (por proyecto)',                    unidad: 'E', precio: 0, horas_unidad: 8.00, codigo: '20-MISC',  cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: 'BARRERA ICRA / CONTENCIÓN DE POLVO (por barrera)',             unidad: 'E', precio: 0, horas_unidad: 4.00, codigo: '01-DEMO',  cero_motivo: 'tarifa', cero_revisado: '2026-09-18' },
  { item: 'LIFT O ANDAMIO — MONTAJE Y MOVIMIENTO (por día)',              unidad: 'E', precio: 0, horas_unidad: 1.00, codigo: '20-MISC',  cero_motivo: 'tarifa', cero_revisado: '2026-09-18' },
  { item: 'PERMISO E INSPECCIONES (por proyecto)',                        unidad: 'E', precio: 0, horas_unidad: 6.00, codigo: '20-MISC',  cero_motivo: 'tarifa', cero_revisado: '2026-09-18' },
  { item: 'MOVILIZACIÓN Y ACARREO (por viaje)',                           unidad: 'E', precio: 0, horas_unidad: 4.00, codigo: '20-MISC',  cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: '1P 20A BREAKER',                    unidad: 'E', precio: 12.5,  horas_unidad: 0.20, codigo: '05-PANEL' },
  { item: 'DUPLEX RECEPTACLE 20A',             unidad: 'E', precio: 3.1,   horas_unidad: 0.30, codigo: '10-DEV' },
  { item: '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', unidad: 'E', precio: 120, horas_unidad: 0.60, codigo: '10-DEV' },
  { item: 'PIR OCCUPANCY SENSOR',              unidad: 'E', precio: 66.16, horas_unidad: 1.26, codigo: '10-DEV' },
  { item: '4"X4" BLANK COVER',                 unidad: 'E', precio: 0.80,  horas_unidad: 0.07, codigo: '09-COND' },
  { item: 'LUMINARIA 2X2 — SOLO INSTALACIÓN',  unidad: 'E', precio: 0,     horas_unidad: 0.75, codigo: '11-LIGHT', cero_motivo: 'solo_labor', cero_revisado: '2026-09-18' },
  { item: '1/2"  EMT CONDUIT',                 unidad: 'LF', precio: 0.61, horas_unidad: 0.03, codigo: '09-COND' }
];
/* El estimado: lo que hay de verdad en Nicklaus, en corto. */
const EST_ID = 'nch';
const ITEMS = [
  { id: 'i1', estimado_id: EST_ID, item: '1P 20A BREAKER',                    unidad: 'E', precio: 12.5,  horas: 0.20, cantidad: 47 },
  { id: 'i2', estimado_id: EST_ID, item: 'DUPLEX RECEPTACLE 20A',             unidad: 'E', precio: 3.1,   horas: 0.30, cantidad: 95 },
  { id: 'i3', estimado_id: EST_ID, item: '0-10V DIMMER / OCCUPANCY SENSOR WALL SWITCH', unidad: 'E', precio: 120, horas: 0.60, cantidad: 22 },
  { id: 'i4', estimado_id: EST_ID, item: 'PIR OCCUPANCY SENSOR',              unidad: 'E', precio: 66.16, horas: 1.26, cantidad: 9 },
  { id: 'i5', estimado_id: EST_ID, item: '4"X4" BLANK COVER',                 unidad: 'E', precio: 0.80,  horas: 0.07, cantidad: 30 },
  { id: 'i6', estimado_id: EST_ID, item: 'LUMINARIA 2X2 — SOLO INSTALACIÓN',  unidad: 'E', precio: 0,     horas: 0.75, cantidad: 55 },
  { id: 'i7', estimado_id: EST_ID, item: '1/2"  EMT CONDUIT',                 unidad: 'LF', precio: 0.61, horas: 0.03, cantidad: 6039 },
  /* LAS TRAMPAS DEL ESTIMADO REAL (18/09, el que se le mandó al cliente): un
     accesorio con la palabra FIXTURE y 264 unidades, un cable de dimming por
     MLF, y los propios renglones de mano que esta tarjeta propone — que se
     contaban a sí mismos y hacían crecer la demolición cada vez. */
  { id: 'x1', estimado_id: EST_ID, item: 'FIXTURES HOLDER CLIPS',              unidad: 'E',   precio: 0.45, horas: 0.10, cantidad: 264 },
  { id: 'x2', estimado_id: EST_ID, item: '18/2 CMP 0-10V DIMMING CABLE (PURPLE/GRAY)', unidad: 'MLF', precio: 330, horas: 8, cantidad: 1 },
  { id: 'x3', estimado_id: EST_ID, item: 'PUESTA EN MARCHA DIMMER 0-10V / SENSOR (por unidad)', unidad: 'E', precio: 0, horas: 0.25, cantidad: 31 },
  { id: 'x4', estimado_id: EST_ID, item: 'DEMOLICIÓN DE DISPOSITIVO O LUMINARIA EXISTENTE (por unidad)', unidad: 'E', precio: 0, horas: 0.35, cantidad: 80 },
  // las cinco que esperan la cuota del supply, con los nombres tal cual los mandó Planos
  { id: 'c1', estimado_id: EST_ID, origen: 'cotizacion', unidad: 'E', precio: 0, horas: 0, cantidad: 25,
    item: 'COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 5000LM 80CRI 35K COL MINI ZT MVOLT (ref. $150, pedir a Jose)' },
  { id: 'c2', estimado_id: EST_ID, origen: 'cotizacion', unidad: 'E', precio: 0, horas: 0, cantidad: 23,
    item: 'COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 2000LM 80CRI 35K COL MINI0 ZT MVOLT' },
  { id: 'c3', estimado_id: EST_ID, origen: 'cotizacion', unidad: 'E', precio: 0, horas: 0, cantidad: 20,
    item: 'COTIZACIÓN PENDIENTE — LITHONIA SCR 22 HC IC L6 35 90C IC E UN — CLEANROOM 2X2 TR' },
  { id: 'c4', estimado_id: EST_ID, origen: 'cotizacion', unidad: 'E', precio: 0, horas: 0, cantidad: 3,
    item: 'COTIZACIÓN PENDIENTE — LITHONIA LDN4 35/10 LO4 WR MVOLT GZ10 — 4" ROUND RECESSED' },
  { id: 'c5', estimado_id: EST_ID, origen: 'cotizacion', unidad: 'E', precio: 0, horas: 0, cantidad: 7,
    item: 'COTIZACIÓN PENDIENTE — LITHONIA LQM S W R G MVOLT M6 — THERMOPLASTIC EXIT SIGN w/E' }
];
const EST = { id: EST_ID, nombre: 'NCH', modo: 'remodelacion', escenario: 'A', factor: 1, estado: 'borrador' };

(async () => {
  await new Promise(r => srv.listen(8892, r));
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const ctx = await b.newContext({ viewport: { width: 1280, height: 900 }, serviceWorkers: 'block' });
  const p = await ctx.newPage(); const errs = [];
  p.on('pageerror', e => errs.push(String(e).slice(0, 160)));
  p.on('console', m => { if (m.type() === 'error' && !/favicon|manifest|supabase|Failed to load/i.test(m.text())) errs.push('console: ' + m.text().slice(0, 120)); });
  await p.goto('http://localhost:8892/index.html'); await p.waitForTimeout(700);
  const datos = (cfg) => p.evaluate(([c, i, cf]) => window.MXP_PRUEBA.e0.datos({ catalogo: c, items: i, config: cf, estimados: [], escenarios: [], ensambleItems: [] }), [CAT, ITEMS, cfg || {}]);
  await datos();

  /* ===== 1 · lo que el estimado dice de sí mismo ===== */
  const cu = await p.evaluate(i => window.MXP_PRUEBA.e0.cuentas(i), ITEMS);
  ok('cuenta 47 circuitos por los breakers', cu.ckt === 47, JSON.stringify(cu));
  ok('cuenta 126 dispositivos (95 tomas + 22 combos + 9 sensores) y NO las tapas ni las cajas', cu.dispositivo === 126, cu.dispositivo);
  ok('cuenta 31 dimmers: NO se cuenta a sí misma la línea de puesta en marcha, ni el cable de dimming por MLF', cu.dimmer === 31, cu.dimmer);
  ok('cuenta 55 luminarias: los 264 FIXTURES HOLDER CLIPS son clips, no luminarias', cu.luminaria === 55, cu.luminaria);
  ok('y la línea de DEMOLICIÓN no entra en el número del que sale la demolición (se mordía la cola)', cu.demo === 181, cu.demo);

  /* ===== 2 · la propuesta de horas ===== */
  const h = await p.evaluate(([i, e]) => window.MXP_PRUEBA.e0.horas(i, e, {}), [ITEMS, EST]);
  const f = id => h.filas.find(x => x.id === id);
  ok('propone las nueve reglas, con su ítem del catálogo', h.filas.length === 9 && h.avisos.length === 0, h.filas.length + ' filas · ' + h.avisos.join(' | '));
  ok('terminar y rotular circuitos: 47 y 47', f('terminacion').cantidad === 47 && f('rotulado').cantidad === 47, JSON.stringify([f('terminacion').cantidad, f('rotulado').cantidad]));
  ok('puesta en marcha 0-10V: 31', f('arranque').cantidad === 31, f('arranque').cantidad);
  ok('demolición: 181 y marcada SUPUESTO (126 dispositivos + 55 luminarias)', f('demo').cantidad === 181 && f('demo').supuesto === true, JSON.stringify(f('demo')));
  ok('ICRA, lift, movilización: uno cada uno y también SUPUESTO', f('icra').cantidad === 1 && f('icra').supuesto && f('lift').supuesto && f('movilizacion').supuesto, '');
  ok('permiso y cierre: uno, y NO son supuesto (todo trabajo lleva uno)', f('permiso').cantidad === 1 && !f('permiso').supuesto && !f('cierre').supuesto, '');
  const horasSeguras = ['terminacion', 'rotulado', 'arranque', 'permiso', 'cierre'].reduce((s, id) => s + f(id).cantidad * f(id).horas, 0);
  ok('lo que se deduce sin suponer nada son 49,95 h (23,5 + 4,7 + 7,75 + 6 + 8)', Math.abs(horasSeguras - 49.95) < 0.05, horasSeguras);

  /* ===== 3 · lo que ya está puesto y los modos ===== */
  const conYa = await p.evaluate(([i, e]) => window.MXP_PRUEBA.e0.horas(
    i.concat([{ estimado_id: 'nch', item: 'AS-BUILT, PRUEBAS Y CIERRE (por proyecto)', unidad: 'E', precio: 0, horas: 8, cantidad: 1 }]), e, {}), [ITEMS, EST]);
  ok('si un renglón YA está en el estimado, lo dice (no lo duplica a ciegas)', conYa.filas.find(x => x.id === 'cierre').ya === 1, JSON.stringify(conYa.filas.find(x => x.id === 'cierre')));
  const enPlanos = await p.evaluate(([i, e]) => window.MXP_PRUEBA.e0.horas(i, Object.assign({}, e, { modo: 'planos' }), {}), [ITEMS, EST]);
  ok('en un trabajo de obra nueva no se proponen demolición ni ICRA', !enPlanos.filas.find(x => x.id === 'demo') && !enPlanos.filas.find(x => x.id === 'icra') && enPlanos.filas.length === 7, enPlanos.filas.map(x => x.id).join(','));
  const ov = await p.evaluate(([i, e]) => window.MXP_PRUEBA.e0.horas(i, e, { horas_proyecto: '{"movilizacion":3,"demo":0.5}' }), [ITEMS, EST]);
  ok('lo que Edgar corrija manda: 3 viajes y media pieza demolida por pieza nueva', ov.filas.find(x => x.id === 'movilizacion').cantidad === 3 && ov.filas.find(x => x.id === 'demo').cantidad === 91, JSON.stringify([ov.filas.find(x => x.id === 'movilizacion').cantidad, ov.filas.find(x => x.id === 'demo').cantidad]));
  await p.evaluate(([c, i]) => window.MXP_PRUEBA.e0.datos({ catalogo: c.filter(x => !/ICRA|LIFT|PERMISO|MOVILIZ/.test(x.item)), items: i, config: {}, escenarios: [] }), [CAT, ITEMS]);
  const sinCat = await p.evaluate(([i, e]) => window.MXP_PRUEBA.e0.horas(i, e, {}), [ITEMS, EST]);
  ok('si falta el ítem en el catálogo la regla no corre pero AVISA y nombra el SQL', sinCat.filas.length === 5 && sinCat.avisos.length === 4 && /e27/.test(sinCat.avisos[0]), sinCat.avisos[0]);
  const sinBrk = await p.evaluate(([c, i, e]) => { window.MXP_PRUEBA.e0.datos({ catalogo: c, items: i, config: {}, escenarios: [] }); return window.MXP_PRUEBA.e0.horas(i.filter(x => !/BREAKER/.test(x.item)), e, {}); }, [CAT, ITEMS, EST]);
  ok('sin breakers en el estimado avisa en vez de poner 0 en silencio', /No encuentro breakers/.test(sinBrk.avisos.join(' ')), sinBrk.avisos.join(' | '));

  /* ===== 4 · de qué familia es cada luminaria ===== */
  await datos();
  const fam = await p.evaluate(() => ({
    stak: window.MXP_PRUEBA.e0.familia('COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 5000LM 80CRI 35K COL MINI ZT MVOLT (ref. $150)'),
    clean: window.MXP_PRUEBA.e0.familia('LITHONIA SCR 22 HC IC L6 35 90C IC E UN — CLEANROOM 2X2 TR'),
    ldn: window.MXP_PRUEBA.e0.familia('LITHONIA LDN4 35/10 LO4 WR MVOLT GZ10 — 4" ROUND RECESSED'),
    exit: window.MXP_PRUEBA.e0.familia('LITHONIA LQM S W R G MVOLT M6 — THERMOPLASTIC EXIT SIGN w/E'),
    dosx4: window.MXP_PRUEBA.e0.familia('LITHONIA BLT 2X4 4000LM'),
    nada: window.MXP_PRUEBA.e0.familia('PNEUMATIC TUBE STATION XYZZY')
  }));
  ok('la cleanroom NO se cuela como troffer 2x2 aunque diga 2X2 (es la cara: $550)', fam.clean === 'cleanroom', JSON.stringify(fam));
  ok('STAK 2x2 → troffer 2x2 · LDN4 → downlight · LQM → exit · BLT 2x4 → troffer 2x4', fam.stak === 'troffer22' && fam.ldn === 'downlight' && fam.exit === 'exit' && fam.dosx4 === 'troffer24', JSON.stringify(fam));
  ok('lo que no reconoce se queda sin familia (no se inventa un precio)', fam.nada === null, fam.nada);

  /* ===== 4b · B2 (20/09) · LA FAMILIA QUE EDGAR ENSEÑA =====
     Las palabras reconocen nueve familias; el mundo tiene más. Lo que Edgar
     elija en el renglón manda sobre lo automático, se guarda POR MODELO para
     todos los estimados, y se puede olvidar. */
  const RARO = 'COTIZACIÓN PENDIENTE — ACUITY OR-7 QUIRÓFANO LED 24V (pedir a Jose)';
  const rf0 = await p.evaluate(m => window.MXP_PRUEBA.e0.luzRef(m, {}), RARO);
  ok('una luminaria que no casa ninguna familia sale sin precio y se dice de dónde viene (fuente «sin»)', rf0.fuente === 'sin' && rf0.precio === 0 && rf0.fam === null, JSON.stringify(rf0));
  ok('la clave con que se aprende es el MODELO: sin «COTIZACIÓN PENDIENTE» y sin los paréntesis del recordatorio',
    (await p.evaluate(m => window.MXP_PRUEBA.e0.luzClave(m), RARO)) === 'ACUITY OR-7 QUIRÓFANO LED 24V', await p.evaluate(m => window.MXP_PRUEBA.e0.luzClave(m), RARO));
  // Edgar le dice que es un troffer 2x4
  const mapa1 = await p.evaluate(m => window.MXP_PRUEBA.e0.luzAprende({}, m, 'troffer24'), RARO);
  const cfg1 = { luz_fam: JSON.stringify(mapa1) };
  const rf1 = await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), [RARO, cfg1]);
  ok('en cuanto Edgar elige la familia, el renglón vale lo de esa familia y se ve que la elegiste tú', rf1.fuente === 'tuya' && rf1.precio === 180 && rf1.id === 'troffer24', JSON.stringify(rf1));
  ok('y lo aprendido se guarda por modelo, no por estimado: el mismo modelo en otro bid ya lo sabe',
    (await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m + ' — OTRO BID', c), ['ACUITY OR-7 QUIRÓFANO LED 24V', cfg1])).fuente === 'sin'
    && (await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), ['ACUITY OR-7 QUIRÓFANO LED 24V (cuota 2026-09-20)', cfg1])).fuente === 'tuya', 'la clave es el modelo pelado');
  // …o un precio suyo, cuando ninguna familia sirve
  const cfg2 = { luz_fam: JSON.stringify(await p.evaluate(m => window.MXP_PRUEBA.e0.luzAprende({}, m, 320), RARO)) };
  const rf2 = await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), [RARO, cfg2]);
  ok('si ninguna familia sirve, un precio suyo para ese modelo: $320, y no finge ser una familia', rf2.fuente === 'precio' && rf2.precio === 320 && rf2.fam === null, JSON.stringify(rf2));
  // corregir lo que la app reconoció MAL
  const CLEAN = 'LITHONIA SCR 22 HC IC L6 35 90C IC E UN — CLEANROOM 2X2 TR';
  const cfg3 = { luz_fam: JSON.stringify(await p.evaluate(m => window.MXP_PRUEBA.e0.luzAprende({}, m, 'troffer22'), CLEAN)) };
  const rf3 = await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), [CLEAN, cfg3]);
  ok('lo de Edgar manda también para CORREGIR: la cleanroom que él marca 2x2 vale 150, no 550', rf3.fuente === 'tuya' && rf3.precio === 150, JSON.stringify(rf3));
  // olvidar → vuelve a lo automático
  const cfg4 = { luz_fam: JSON.stringify(await p.evaluate(([c, m]) => window.MXP_PRUEBA.e0.luzAprende(c, m, ''), [cfg3, CLEAN])) };
  const rf4 = await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), [CLEAN, cfg4]);
  ok('al olvidarlo vuelve a lo automático (cleanroom, 550) y el mapa queda vacío', rf4.fuente === 'auto' && rf4.precio === 550 && Object.keys(JSON.parse(cfg4.luz_fam)).length === 0, JSON.stringify([rf4, cfg4.luz_fam]));
  ok('un precio de 0 o negativo no se guarda: es olvidar, no regalar la luminaria',
    Object.keys(await p.evaluate(([c, m]) => window.MXP_PRUEBA.e0.luzAprende(c, m, 0), [cfg3, CLEAN])).length === 0
    && Object.keys(await p.evaluate(([c, m]) => window.MXP_PRUEBA.e0.luzAprende(c, m, -5), [cfg3, CLEAN])).length === 0, '');
  // lo guardado que no se entiende no puede tumbar el bid
  const malos = await p.evaluate(m => [
    window.MXP_PRUEBA.e0.luzRef(m, { luz_fam: 'esto no es json' }),
    window.MXP_PRUEBA.e0.luzRef(m, { luz_fam: '[1,2,3]' }),
    window.MXP_PRUEBA.e0.luzRef(m, { luz_fam: '{"ACUITY OR-7 QUIRÓFANO LED 24V":"familia_que_no_existe"}' }),
    window.MXP_PRUEBA.e0.luzRef(m, { luz_fam: '{"ACUITY OR-7 QUIRÓFANO LED 24V":{"a":1}}' })
  ], RARO);
  ok('un luz_fam roto, una lista, una familia que ya no existe o un valor raro: se ignoran y manda lo automático', malos.every(x => x.fuente === 'sin' && x.precio === 0), JSON.stringify(malos.map(x => x.fuente)));
  // el tope: lo viejo cae, lo recién enseñado nunca (21/09: el tope duro es 600)
  const tope = await p.evaluate(() => {
    let m = {};
    for (let i = 0; i < 605; i++) m = window.MXP_PRUEBA.e0.luzAprende({ luz_fam: JSON.stringify(m) }, 'MODELO ' + i, 'exit');
    const k = Object.keys(m);
    return { n: k.length, primera: k[0], ultima: k[k.length - 1] };
  });
  ok('lo aprendido no crece sin fin: tope de 600 modelos, cae el más viejo y se queda el último', tope.n === 600 && tope.primera === 'MODELO 5' && tope.ultima === 'MODELO 604', JSON.stringify(tope));
  ok('por debajo del tope no se olvida nada: 300 modelos siguen siendo 300', (await p.evaluate(() => { let m = {}; for (let i = 0; i < 300; i++) m = window.MXP_PRUEBA.e0.luzAprende({ luz_fam: JSON.stringify(m) }, 'M ' + i, 'exit'); return Object.keys(m).length; })) === 300);
  // y el dinero: lo aprendido entra al total como cualquier referencia
  const ITEMS_RARO = ITEMS.map(x => x.id === 'c3' ? Object.assign({}, x, { item: RARO }) : x);
  const ITEMS_RARO0 = [ITEMS_RARO.find(x => x.id === 'c3')];
  const refSin = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i, {}), ITEMS_RARO);
  const refCon = await p.evaluate(([i, c]) => window.MXP_PRUEBA.e0.refLuz(i, c), [ITEMS_RARO, cfg2]);
  ok('con el modelo raro sin enseñar, sus 20 unidades no suman nada y el renglón sale señalado', refSin.sinFamilia.length === 1 && refSin.total === 19630 - 11000, JSON.stringify([refSin.sinFamilia.length, refSin.total]));
  ok('enseñándole el precio ($320 × 20) el bid deja de salir corto: entra al total y ya nadie queda sin familia', refCon.sinFamilia.length === 0 && refCon.total === 19630 - 11000 + 6400, JSON.stringify([refCon.sinFamilia.length, refCon.total]));
  ok('y la fila dice de dónde salió el precio, para que no se confunda con una cotización', (refCon.filas.find(x => x.familia === 'propio') || {}).fuente === 'precio', JSON.stringify(refCon.filas.map(x => [x.familia, x.fuente])));
  // el chip del renglón
  const chipRaro = await p.evaluate(([l, e, c]) => { window.MXP_PRUEBA.e0.datos({ catalogo: [], config: c, ensambleItems: [], estimados: [] }); return window.MXP_PRUEBA.e0.cero(l, Object.assign({}, e, { usa_luz_ref: true })); },
    [ITEMS_RARO.find(x => x.id === 'c3'), EST, cfg2]);
  ok('el renglón de la luminaria enseñada dice REFERENCIA con el precio de Edgar, y sigue avisando que falta la cuota', chipRaro.est === 'referencia' && /320/.test(chipRaro.chip) && chipRaro.alerta === true, chipRaro.chip);
  await datos();

  /* ===== 4c · lo que sacó la revisión adversaria del 20/09 ===== */
  // «olvidar» borra por la clave EXACTA de la lista, sin volver a normalizarla
  const conEspacio = { luz_fam: JSON.stringify({ 'MODELO RARO QUE SE CORTO ': 'exit', 'OTRO': 'highbay' }) };
  const olv = await p.evaluate(c => window.MXP_PRUEBA.e0.luzOlvida(c, 'MODELO RARO QUE SE CORTO '), conEspacio);
  ok('«olvidar» borra la entrada aunque su clave acabe en espacio (antes la re-normalizaba y no borraba nada)', Object.keys(olv).join() === 'OTRO', JSON.stringify(Object.keys(olv)));
  // dos renglones seguidos no se pisan: el segundo parte del mapa VIVO, no del config viejo
  const carrera = await p.evaluate(() => {
    window.MXP_PRUEBA.e0.luzMem(null);
    const cfgVacia = {};
    const uno = window.MXP_PRUEBA.e0.luzAprende(cfgVacia, 'LUMINARIA A', 'exit');
    window.MXP_PRUEBA.e0.luzMem(uno);                       // como lo deja aprendeFamLuz antes de guardar
    const base = { luz_fam: JSON.stringify(window.MXP_PRUEBA.e0.luzActual()) };
    const dos = window.MXP_PRUEBA.e0.luzAprende(base, 'LUMINARIA B', 'highbay');
    window.MXP_PRUEBA.e0.luzMem(null);
    return Object.keys(dos);
  });
  ok('enseñar dos luminarias seguidas conserva las DOS: la segunda parte del mapa vivo, no del guardado', carrera.join() === 'LUMINARIA A,LUMINARIA B', JSON.stringify(carrera));
  // una familia cuyo precio de referencia está en $0 no se pinta como resuelta
  const cfg0 = { luz_fam: JSON.stringify({ [RARO.replace(/^COTIZACIÓN PENDIENTE — /, '').replace(/\s*\([^)]*\)/g, '').trim()]: 'exit' }), luz_ref: '{"exit":0}' };
  const rf0b = await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), [RARO, cfg0]);
  ok('una familia elegida cuyo precio está en $0 se dice a medias («tuya_sin_precio»), no como resuelta', rf0b.fuente === 'tuya_sin_precio' && rf0b.precio === 0, JSON.stringify(rf0b));
  const ref0 = await p.evaluate(([i, c]) => window.MXP_PRUEBA.e0.refLuz(i, c), [ITEMS_RARO0, cfg0]);
  ok('…y sigue contando como renglón sin precio, para que el bid no salga corto sin avisar', ref0.sinFamilia.length === 1, JSON.stringify(ref0.sinFamilia.map(x => x.modelo)));
  // el aviso de salida no puede decir que el precio NO incluye lo que SÍ incluye
  await datos(cfg2);
  const salOn = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.salida(Object.assign({}, e, { usa_luz_ref: true }), c), [EST, { items: ITEMS_RARO, autos: [] }]);
  const salOff = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.salida(e, c), [EST, { items: ITEMS_RARO, autos: [] }]);
  ok('al salir, las luminarias a precio de referencia se dicen APARTE: ese dinero SÍ está en el precio', /TU PRECIO DE REFERENCIA/.test(salOn) && /S[IÍ] est[aá] en el precio/.test(salOn), salOn.slice(0, 130));
  ok('y avisa de lo que importa: si el supply viene más caro, la diferencia la pone Edgar', /la diferencia la pones t[uú]/i.test(salOn), '');
  ok('sin la referencia encendida, el aviso sigue siendo el de siempre («el precio NO los incluye»)', !/PRECIO DE REFERENCIA/.test(salOff) && /NO los incluye/.test(salOff), salOff.slice(0, 90));
  await datos();
  // la segunda cuota, la más cara, gana aunque llegue otro día
  const yaCotizado = ITEMS.map(x => x.id === 'c1' ? Object.assign({}, x, { precio: 168.40, origen: 'cotizacion-cuota' }) : x);
  const CUOTA2 = '25  LITHONIA STAK 2X2 5000LM 80CRI 35K COL MINI ZT MVOLT   $181.00   $4,525.00';
  const mas = await p.evaluate(([t, i]) => window.MXP_PRUEBA.e0.casaCuota(t, i.filter(x => x.origen === 'cotizacion' || x.origen === 'cotizacion-cuota')), [CUOTA2, yaCotizado]);
  const c1 = mas.casadas.find(x => /5000LM/.test(x.modelo));
  ok('una segunda cuota MÁS CARA que llega otro día vuelve a casar con el renglón ya cotizado', !!c1 && c1.yaTenia === 168.40, JSON.stringify(c1 && [c1.precio, c1.yaTenia]));
  ok('…y gana, que es la regla de Edgar: prefiere que sobre a que falte', c1.gana === true && c1.precio === 181, JSON.stringify([c1.gana, c1.precio]));
  const CUOTA3 = '25  LITHONIA STAK 2X2 5000LM 80CRI 35K COL MINI ZT MVOLT   $140.00   $3,500.00';
  const menos = await p.evaluate(([t, i]) => window.MXP_PRUEBA.e0.casaCuota(t, i.filter(x => x.origen === 'cotizacion' || x.origen === 'cotizacion-cuota')), [CUOTA3, yaCotizado]);
  const c2 = menos.casadas.find(x => /5000LM/.test(x.modelo));
  ok('si la segunda viene más BARATA se ve, pero no gana: no se toca el precio que ya estaba', !!c2 && c2.gana === false && c2.yaTenia === 168.40, JSON.stringify(c2 && [c2.precio, c2.gana]));

  // la clave conserva lo que describe la luminaria y tira solo los recordatorios
  const claves = await p.evaluate(() => [
    window.MXP_PRUEBA.e0.luzClave('COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 (5000LM) ZT MVOLT (ref. $150, pedir a Jose)'),
    window.MXP_PRUEBA.e0.luzClave('COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 (2000LM) ZT MVOLT'),
    window.MXP_PRUEBA.e0.luzClave('LITHONIA STAK 2X2 (5000LM) ZT MVOLT (cuota 2026-09-20)')
  ]);
  ok('la clave NO junta dos luminarias que solo se diferencian en el paréntesis: 5000LM y 2000LM son distintas', claves[0] !== claves[1] && /5000LM/.test(claves[0]) && /2000LM/.test(claves[1]), JSON.stringify(claves.slice(0, 2)));
  ok('…pero el recordatorio («ref. $150, pedir a Jose») y la marca de la cuota sí se tiran: el mismo modelo sigue siendo el mismo', claves[0] === claves[2], JSON.stringify([claves[0], claves[2]]));
  // el tope nunca se lleva lo que se acaba de enseñar, ni con una clave que es solo números
  const topeNum = await p.evaluate(() => {
    let m = {};
    for (let i = 0; i < 600; i++) m = window.MXP_PRUEBA.e0.luzAprende({ luz_fam: JSON.stringify(m) }, 'MODELO ' + i, 'exit');
    m = window.MXP_PRUEBA.e0.luzAprende({ luz_fam: JSON.stringify(m) }, '4096', 'highbay');   // una clave de solo dígitos
    return { n: Object.keys(m).length, guardado: m['4096'] };
  });
  ok('con el mapa lleno, enseñar un modelo que es solo números NO se borra a sí mismo (JS pone las claves numéricas primero)', topeNum.guardado === 'highbay' && topeNum.n === 600, JSON.stringify(topeNum));
  /* (21/09, verificación) Y EL ORDEN DE CADUCAR. JS coloca las claves enteras
     ANTES que las de texto, así que un modelo llamado «10642» salía primero de
     la lista y caía antes que familias muchísimo más viejas. Ahora las de texto
     —que sí guardan el orden en que se aprendieron— caducan primero. */
  const ordenTope = await p.evaluate(() => {
    let m = { '10642': 'highbay' };   // la numérica, la PRIMERA que se aprendió
    for (let i = 0; i < 600; i++) m = window.MXP_PRUEBA.e0.luzAprende({ luz_fam: JSON.stringify(m) }, 'TXT ' + i, 'exit');
    return { n: Object.keys(m).length, numSigue: m['10642'], txt0: m['TXT 0'], ultimo: m['TXT 599'] };
  });
  ok('al caducar, cae la de TEXTO más vieja y la numérica no se lleva el golpe por ser numérica', ordenTope.numSigue === 'highbay' && ordenTope.txt0 === undefined && ordenTope.ultimo === 'exit' && ordenTope.n === 600, JSON.stringify(ordenTope));
  // un precio ridículo no tapa el aviso de que el renglón va sin dinero
  const cfgFlojo = { luz_fam: JSON.stringify({ [await p.evaluate(m => window.MXP_PRUEBA.e0.luzClave(m), RARO)]: 0.5 }) };
  const rfFlojo = await p.evaluate(([m, c]) => window.MXP_PRUEBA.e0.luzRef(m, c), [RARO, cfgFlojo]);
  const refFlojo = await p.evaluate(([i, c]) => window.MXP_PRUEBA.e0.refLuz(i, c), [ITEMS_RARO0, cfgFlojo]);
  ok('un precio de 50 centavos se marca como flojo y sigue contando como renglón sin precio: un dedazo no tapa el aviso', rfFlojo.flojo === true && refFlojo.sinFamilia.length === 1, JSON.stringify([rfFlojo.precio, rfFlojo.flojo, refFlojo.sinFamilia.length]));

  /* ===== 5 · el precio de referencia ===== */
  const ref = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i, {}), ITEMS);
  ok('las cinco líneas pendientes llevan referencia, ninguna se queda fuera', ref.filas.length === 5 && ref.sinFamilia.length === 0, JSON.stringify(ref.filas.map(x => [x.familia, x.precio])));
  ok('el total de referencia son $19.630 (25×150 + 23×150 + 20×550 + 3×220 + 7×110)', ref.total === 19630, ref.total);
  const refOv = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i, { luz_ref: '{"cleanroom":610,"troffer22":168}' }), ITEMS);
  ok('los precios que Edgar guarde mandan sobre los de arranque (cleanroom 610, 2x2 168)', refOv.total === 21694, refOv.total);
  const refMal = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i.map(x => x.id === 'c3' ? Object.assign({}, x, { item: 'COTIZACIÓN PENDIENTE — ARTEFACTO RARO XYZ' }) : x), {}), ITEMS);
  ok('una luminaria de familia desconocida no suma nada y se señala', refMal.sinFamilia.length === 1 && refMal.total === 19630 - 11000, JSON.stringify([refMal.sinFamilia.length, refMal.total]));

  /* ===== 5b · SUJETO A COTIZACIÓN en el papel que firma el cliente (20/09) ===== */
  await datos();
  const cRef = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(Object.assign({}, e, { usa_luz_ref: true })), EST);
  const cOff = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), EST);
  const propOn = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propuesta(Object.assign({}, e, { usa_luz_ref: true }), c), [EST, cRef]);
  const propOff = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.propuesta(e, c), [EST, cOff]);
  ok('con la referencia encendida, la propuesta dice SUJETO A COTIZACIÓN y lista las luminarias', /SUJETO A COTIZACI[OÓ]N DEL SUMINISTRO/.test(propOn) && /SUBJECT TO SUPPLIER QUOTE/.test(propOn), (propOn.match(/SUJETO[^\n]*/) || [""])[0]);
  ok('dice que SÍ están incluidas en el precio (no es una exclusión) y que el ajuste va por Change Order', /INCLUIDAS en el precio total a valor de referencia/.test(propOn) && /Change Order antes de ordenar el material/.test(propOn), '');
  ok('lista las cinco luminarias con su cantidad y su modelo', /• 25 × LITHONIA STAK 2X2 5000LM/.test(propOn) && (propOn.match(/• \d+ × LITHONIA/g) || []).length === 5, JSON.stringify((propOn.match(/• \d+ × LITHONIA[^\n]{0,24}/g) || []).slice(0, 2)));
  ok('y NO enseña ningún precio unitario de las luminarias: el cliente no ve lo que Edgar paga', !/150|550|220|110\.00/.test((propOn.split("SUJETO A COTIZACIÓN")[1] || "").split("PRECIO TOTAL")[0]), '');
  ok('el precio total sigue siendo el mismo número de siempre', new RegExp("PRECIO TOTAL \\(LUMP SUM\\): " + (await p.evaluate(c => window.MXP_PRUEBA.e0 && (Math.round(c.bid * 100) / 100).toLocaleString("en-US", { style: "currency", currency: "USD" }), cRef)).replace(/[$,.]/g, x => "\\" + x)).test(propOn), '');
  ok('con la referencia APAGADA la propuesta sale letra por letra como siempre: ni una palabra de cotización', !/SUJETO A COTIZACI/.test(propOff), propOff.slice(0, 60));
  ok('el ALCANCE ya no le enseña al cliente «COTIZACIÓN PENDIENTE» ni el recordatorio con TU precio y a quién se lo pides', !/COTIZACI[OÓ]N PENDIENTE/.test(propOn) && !/ref\. \$150|pedir a Jose/.test(propOn) && !/COTIZACI[OÓ]N PENDIENTE/.test(propOff), (propOn.match(/• GENERAL[^\n]{0,70}/) || [""])[0]);
  ok('…pero sí el modelo de la luminaria, que es lo que el cliente necesita leer', /LITHONIA STAK 2X2 5000LM/.test(propOn), '');
  const nom = await p.evaluate(() => [
    window.MXP_PRUEBA.e0.nombreCliente('COTIZACIÓN PENDIENTE — LITHONIA STAK 2X2 (5000LM) ZT (ref. $150, pedir a Jose)'),
    window.MXP_PRUEBA.e0.nombreCliente('DUPLEX RECEPTACLE 20A (HOSPITAL GRADE)')
  ]);
  ok('se quita el recordatorio pero NO lo que describe la pieza, y un renglón normal no se toca', nom[0] === 'LITHONIA STAK 2X2 (5000LM) ZT' && nom[1] === 'DUPLEX RECEPTACLE 20A (HOSPITAL GRADE)', JSON.stringify(nom));
  const sujNada = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.sujetas(Object.assign({}, e, { usa_luz_ref: true, modo: 'rapido' }), c), [EST, cRef]);
  ok('en modo rápido no hay renglones que mirar: no sale el bloque', sujNada.length === 0, JSON.stringify(sujNada));

  /* ===== 6 · el dinero: apagado no mueve nada, encendido entra como cotización ===== */
  const off = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), EST);
  const on = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(Object.assign({}, e, { usa_luz_ref: true })), EST);
  ok('apagado (por defecto) el bid es el de siempre: la referencia no entra', off.refLuz.total === 0 && Math.abs(off.matCot) < 0.01, JSON.stringify([off.refLuz.total, off.matCot]));
  ok('encendido, los $19.630 entran por la puerta de las COTIZACIONES, no como material propio',
    Math.abs(on.matCot - 19630) < 0.01 && Math.abs(on.matPropio - off.matPropio) < 0.01, JSON.stringify([on.matCot, Math.round(on.matPropio), Math.round(off.matPropio)]));
  ok('y por eso no pagan misceláneas: el misc no se mueve', Math.abs(on.misc - off.misc) < 0.01, JSON.stringify([on.misc, off.misc]));
  ok('el bid sube lo que tiene que subir y las horas no cambian', on.bid > off.bid + 19630 && Math.abs(on.horas - off.horas) < 0.01, JSON.stringify([Math.round(off.bid), Math.round(on.bid), on.horas]));

  /* ===== 6b · CONGELAR CONGELA DE VERDAD (21/09, verificación) =====
     Antes, congelar solo escribía estado:'congelado' y calcularEstimado seguía
     leyendo el catálogo y la configuración VIVOS: enseñarle una familia de
     luminarias por la noche movía el bid de un estimado ya cerrado. Ahora se
     guarda la foto —bid_final— y queda un número contra el que comparar. */
  const congelado = await p.evaluate(e => window.MXP_PRUEBA.e0.foto(Object.assign({}, e, { usa_luz_ref: true, estado: 'congelado' })), EST);
  ok('congelar guarda el número de hoy: bid_final, horas_final y material_final, con fecha',
    Math.abs(congelado.bid_final - on.bid) < 0.02 && Math.abs(congelado.horas_final - on.horas) < 0.02 && congelado.material_final > 0 && /^\d{4}-\d{2}-\d{2}/.test(String(congelado.cerrado_en || '')),
    JSON.stringify([congelado.bid_final, congelado.horas_final, String(congelado.cerrado_en).slice(0, 10)]));
  // y si después se le enseña una familia, el número de hoy YA NO es el congelado: eso es lo que hay que poder ver
  const trasEnsenar = await p.evaluate(([e, c, i]) => {
    const d = window.MXP_PRUEBA.e0;
    const luz = i.find(x => x.id === 'c1');
    const m = d.luzAprende({ luz_fam: '{}' }, luz.item, 900);   // $900 de referencia a esa luminaria
    d.datos({ catalogo: c, items: i, config: { luz_fam: JSON.stringify(m) }, estimados: [], escenarios: [], ensambleItems: [] });
    const bid = d.calcula(Object.assign({}, e, { usa_luz_ref: true, estado: 'congelado' })).bid;
    d.datos({ catalogo: c, items: i, config: {}, estimados: [], escenarios: [], ensambleItems: [] });   // se deja como estaba
    return bid;
  }, [EST, CAT, ITEMS]);
  ok('enseñar una familia DESPUÉS mueve el número vivo de un congelado — por eso hace falta la foto y el aviso de cuánto se movió',
    trasEnsenar > 0 && Math.abs(trasEnsenar - congelado.bid_final) > congelado.bid_final * 0.005,
    JSON.stringify([Math.round(congelado.bid_final), Math.round(trasEnsenar)]));

  /* ===== 7 · lo que se ve en el renglón ===== */
  const LC1 = ITEMS.find(x => x.id === 'c1');   // la STAK 2x2 de 5000 lm, por índice no: el fixture creció
  const chipOff = await p.evaluate(([l, e]) => window.MXP_PRUEBA.e0.cero(l, e), [LC1, EST]);
  const chipOn = await p.evaluate(([l, e]) => window.MXP_PRUEBA.e0.cero(l, Object.assign({}, e, { usa_luz_ref: true })), [LC1, EST]);
  ok('sin referencia el renglón sigue diciendo POR COTIZAR', chipOff.est === 'suministro' && /POR COTIZAR/.test(chipOff.chip), chipOff.chip);
  ok('con referencia dice REFERENCIA y ENSEÑA el precio que se usó', chipOn.est === 'referencia' && /REFERENCIA/.test(chipOn.chip) && /150/.test(chipOn.chip), chipOn.chip);
  ok('y sigue alertando: la cuota de verdad no ha llegado', chipOn.alerta === true && /cuota/.test(chipOn.motivo), chipOn.motivo);

  /* ===== 8 · leer la cuota del supply ===== */
  const CUOTA = `CED GREENTECH MIAMI — QUOTE 884213
QTY   CATALOG NUMBER                                    UNIT      EXT
25    LITHONIA STAK 2X2 5000LM 80CRI 35K COL MINI ZT MVOLT   $168.40   $4,210.00
23    LITHONIA STAK 2X2 2000LM 80CRI 35K COL MINI0 ZT MVOLT  $151.20   $3,477.60
20    LITHONIA SCR 22 HC IC L6 35 90C IC E UN CLEANROOM      $602.75   $12,055.00
 7    LITHONIA LQM S W R G MVOLT M6 EXIT SIGN                 $96.10     $672.70
      SUBTOTAL                                                        $20,415.30
      SALES TAX                                                        $1,429.07
      TOTAL                                                           $21,844.37`;
  const leido = await p.evaluate(t => window.MXP_PRUEBA.e0.leeCuota(t), CUOTA);
  ok('lee las 4 líneas con precio y se salta cabeceras, el número de la cuota, subtotal, tax y total', leido.filas.length === 4, JSON.stringify(leido.filas.map(x => x.precio)));
  ok('el precio que coge es el UNITARIO, no el extendido', leido.filas[0].precio === 168.40 && leido.filas[2].precio === 602.75 && leido.filas[0].cantidad === 25, JSON.stringify(leido.filas.map(x => [x.cantidad, x.precio])));
  const casa = await p.evaluate(([t, i]) => window.MXP_PRUEBA.e0.casaCuota(t, i.filter(x => x.origen === 'cotizacion')), [CUOTA, ITEMS]);
  ok('casa cada modelo con su renglón: 4 de 5', casa.casadas.length === 4, JSON.stringify(casa.casadas.map(x => [x.modelo.slice(0, 22), x.precio])));
  const dc = m => casa.casadas.find(x => new RegExp(m).test(x.modelo));
  ok('no confunde la STAK de 5000 con la de 2000 (un error de $400 en el bid)', dc('5000LM').precio === 168.40 && dc('2000LM').precio === 151.20, JSON.stringify([dc('5000LM').precio, dc('2000LM').precio]));
  ok('el downlight LDN4, que no venía en la cuota, se queda señalado como pendiente', casa.sinCuota.length === 1 && /LDN4/.test(casa.sinCuota[0].item), JSON.stringify(casa.sinCuota.map(x => x.item.slice(0, 40))));
  ok('cada pareja trae el id del renglón, que es lo que se va a escribir', casa.casadas.every(x => x.id), JSON.stringify(casa.casadas.map(x => x.id)));

  /* ===== 9 · dos cuotas: manda la más cara (regla de Edgar) ===== */
  const DOS = CUOTA + `
CES MIAMI — QUOTE 55120
25    LITHONIA STAK 2X2 5000LM 80CRI 35K COL MINI ZT MVOLT   $159.00   $3,975.00
20    LITHONIA SCR 22 HC IC L6 35 90C IC E UN CLEANROOM      $655.00   $13,100.00`;
  const dos = await p.evaluate(([t, i]) => window.MXP_PRUEBA.e0.casaCuota(t, i.filter(x => x.origen === 'cotizacion')), [DOS, ITEMS]);
  const d2 = m => dos.casadas.find(x => new RegExp(m).test(x.modelo));
  ok('con CED y CES pegadas, cada modelo se queda con la MÁS CARA', d2('5000LM').precio === 168.40 && d2('SCR 22').precio === 655.00, JSON.stringify([d2('5000LM').precio, d2('SCR 22').precio]));
  ok('y dice cuál era la otra, para que se vea la diferencia', d2('SCR 22').antes === 602.75, JSON.stringify([d2('SCR 22').antes, d2('5000LM').antes]));

  /* ===== 10 · lo que NO entiende lo dice, no lo adivina ===== */
  const raro = await p.evaluate(([t, i]) => window.MXP_PRUEBA.e0.casaCuota(t, i.filter(x => x.origen === 'cotizacion')),
    ['10  SQUARE D QO120 BREAKER 1P 20A   $8.40   $84.00\n5  IDEAL WIRENUTS RED   $0.12', ITEMS]);
  ok('una cuota de otro material no se casa con ninguna luminaria', raro.casadas.length === 0 && raro.sinPareja.length >= 1, JSON.stringify([raro.casadas.length, raro.sinPareja.length]));

  /* ===== 11 · las tarjetas se PINTAN sin lanzar (el HTML, no solo el motor) ===== */
  await datos();
  const pint = await p.evaluate(e => {
    const c = window.MXP_PRUEBA.e0.calcula(Object.assign({}, e, { soporte: 'unistrut', pct_rack: 0.3, usa_luz_ref: true }));
    const h = window.MXP_PRUEBA.e0.tarjetas(Object.assign({}, e, { soporte: 'unistrut', pct_rack: 0.3, usa_luz_ref: true }), c);
    const d = document.createElement('div'); d.innerHTML = h;
    return { largo: h.length, fallo: /Una tarjeta nueva falló/.test(h),
             consumibles: d.querySelectorAll('.cons-por').length,
             horas: d.querySelectorAll('.horas-chk').length,
             luz: d.querySelectorAll('.luz-ref-precio').length,
             selFam: d.querySelectorAll('select.luz-fam').length,
             opcFam: (d.querySelector('select.luz-fam') || { options: [] }).options.length,
             autoDice: ((d.querySelector('select.luz-fam') || { options: [] }).options[0] || {}).textContent || '',
             elegida: [...d.querySelectorAll('select.luz-fam')].map(x => x.value),
             propios: d.querySelectorAll('.luz-fam-precio').length,
             titulos: [...d.querySelectorAll('.cal-form-titulo')].map(x => x.textContent.trim().slice(0, 22)) };
  }, EST);
  ok('las tres tarjetas se pintan sin lanzar', !pint.fallo && pint.largo > 3000, JSON.stringify([pint.fallo, pint.largo, pint.titulos]));
  ok('la tabla de consumibles trae sus 18 números editables', pint.consumibles === 18, pint.consumibles);
  ok('la de horas trae una casilla por regla y la de luz sus 9 familias', pint.horas === 9 && pint.luz === 9, JSON.stringify([pint.horas, pint.luz]));
  ok('(B2) cada una de las 5 luminarias pendientes trae su selector de familia y su hueco de precio propio', pint.selFam === 5 && pint.propios === 5, JSON.stringify([pint.selFam, pint.propios]));
  ok('el selector ofrece automático + las 9 familias + un precio tuyo, y dice QUÉ reconoció solo', pint.opcFam === 11 && /Autom[áa]tico/.test(pint.autoDice) && /2x2/.test(pint.autoDice), JSON.stringify([pint.opcFam, pint.autoDice]));
  ok('y sin nada enseñado todos salen en «automático» (no se preselecciona una familia que Edgar no eligió)', pint.elegida.every(v => v === ''), JSON.stringify(pint.elegida));
  const CLAVE_LDN = await p.evaluate(i => window.MXP_PRUEBA.e0.luzClave(i), ITEMS.find(x => x.id === 'c4').item);
  await datos({ luz_fam: JSON.stringify({ [CLAVE_LDN]: 'highbay' }) });
  const pintEns = await p.evaluate(e => {
    const est = Object.assign({}, e, { usa_luz_ref: true });
    const c = window.MXP_PRUEBA.e0.calcula(est);
    const d = document.createElement('div'); d.innerHTML = window.MXP_PRUEBA.e0.tarjetas(est, c);
    return { sel: [...d.querySelectorAll('select.luz-fam')].map(x => x.value).filter(Boolean),
             olvidar: d.querySelectorAll('.luz-fam-olvida').length,
             texto: d.textContent.replace(/\s+/g, ' ') };
  }, EST);
  ok('lo enseñado sale ya elegido en su fila, con su ✎, y se puede olvidar desde la lista', pintEns.sel.join() === 'highbay' && pintEns.olvidar === 1 && /✎/.test(pintEns.texto) && /Lo que me enseñaste \(1/.test(pintEns.texto), JSON.stringify([pintEns.sel, pintEns.olvidar]));
  await datos();
  const flojo = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetas(e, { items: null, autos: null }), EST);
  ok('un cálculo a medias (sin ítems ni automáticos) no rompe ninguna tarjeta', !/Una tarjeta nueva falló/.test(flojo), flojo.slice(0, 60));
  const rota = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetas(e, null), EST);
  ok('y si aun así una lanzara, se cae ELLA sola: el estimador sigue en pie', /Una tarjeta nueva falló/.test(rota) && rota.split("Una tarjeta nueva falló").length - 1 >= 1, rota.replace(/\s+/g, ' ').slice(0, 110));

  /* ===== 12 · ¿se corrió la auditoría del catálogo? (20/09) ===== */
  const CAT_VIEJO = [
    { item: '6" GRS CONDUIT', unidad: 'LF', precio: 0, horas_unidad: 0.09 },         // pendiente
    { item: '1/2"   LOCKNUT', unidad: 'E', precio: 0.053, horas_unidad: 0.02 },      // ya hecho (y con espacios distintos)
    { item: 'CAT6 CABLE', unidad: 'MLF', precio: 450, horas_unidad: 25 },            // ya hecho
    { item: 'RG6 TV CABLE', unidad: 'MLF', precio: 0.15, horas_unidad: 0.15 },       // pendiente (dos campos)
    { item: 'JB 1900 DEEP BOX', unidad: 'E', precio: 9.99, horas_unidad: 0.9 }       // Edgar lo cambió a otra cosa
  ];
  const aud = await p.evaluate(c => window.MXP_PRUEBA.e0.auditoria(c), CAT_VIEJO);
  ok('la app mira TU catálogo y dice qué correcciones de la auditoría faltan (no un SQL que nadie sabe si corrió)', aud.total === 33 && aud.pendientes.length === 2, JSON.stringify({ total: aud.total, pend: aud.pendientes.map(x => x.item) }));
  ok('las que ya están hechas no se repiten, aunque el nombre lleve otros espacios', aud.hechos.length === 2 && aud.hechos.some(x => /LOCKNUT/.test(x.item)), JSON.stringify(aud.hechos.map(x => x.item)));
  ok('y lo que Edgar cambió a mano a otro número NO se toca ni se cuenta como pendiente: su número manda', aud.cambiados.length === 1 && /JB 1900/.test(aud.cambiados[0].item), JSON.stringify(aud.cambiados.map(x => x.item)));
  ok('lo que ni siquiera está en el catálogo se aparta, no se inventa', aud.sinItem.length === 33 - 5, aud.sinItem.length);
  const sql = await p.evaluate(ps => window.MXP_PRUEBA.e0.auditoriaSql(ps), aud.pendientes);
  ok('el SQL sale SOLO de las que faltan, con el valor de hoy como condición (si ya lo cambiaste, no hace nada)', /update catalogo_items set horas_unidad = 0.25/.test(sql) && /coalesce\(horas_unidad,0\) = 0.09/.test(sql) && !/LOCKNUT/.test(sql), sql.split("\n")[1]);
  ok('y el de dos campos los lleva los dos', /set precio = 150, horas_unidad = 8/.test(sql) && /coalesce\(precio,0\) = 0.15 and coalesce\(horas_unidad,0\) = 0.15/.test(sql), (sql.match(/set precio = 150[^\n]*/) || [""])[0]);
  const audOk = await p.evaluate(() => window.MXP_PRUEBA.e0.auditoria([{ item: 'NADA QUE VER', precio: 1 }]));
  ok('con un catálogo donde no está ninguna, no hay pendientes que enseñar (la tarjeta no sale)', audOk.pendientes.length === 0, JSON.stringify([audOk.pendientes.length, audOk.sinItem.length]));
  const tarj = await p.evaluate(([cv, e]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: cv, items: [{ id: 'z', item: '6" GRS CONDUIT', cantidad: 100, precio: 0, horas: 0.09, unidad: 'LF' }], config: {}, estimados: [] });
    const h = window.MXP_PRUEBA.e0.tarjetas(e, { items: [{ id: 'z', item: '6" GRS CONDUIT', cantidad: 100, precio: 0, horas: 0.09, unidad: 'LF' }], autos: [] });
    const d = document.createElement('div'); d.innerHTML = h;
    return { sale: /La auditor[ií]a del cat[aá]logo/.test(h), enBid: /EN ESTE BID/.test(h), sql: (d.querySelector('#aud-sql') || {}).value || '' };
  }, [CAT_VIEJO, EST]);
  ok('la tarjeta sale en el estimador y marca las que están en ESTE bid', tarj.sale && tarj.enBid && /GRS CONDUIT/.test(tarj.sql), JSON.stringify([tarj.sale, tarj.enBid]));
  await datos();

  /* ===== 13 · el conector que no le cabe al cable (defecto conocido desde el 16/09) ===== */
  const ENS = [{ id: 'ev', nombre: 'EV CHARGER OUTLET (NEMA 14-50)' }, { id: 'gfci', nombre: 'RECEPTÁCULO GFCI 20A WP EXTERIOR — ROMEX' }, { id: 'sec', nombre: 'RECEPTÁCULO 30A SECADORA — ROMEX' }];
  const ENSI = [
    { ensamble_id: 'ev', item: '6/3     ROMEX', cantidad: 0.025 },
    { ensamble_id: 'ev', item: 'NM CABLE CONNECTOR 1/2"', cantidad: 1 },
    { ensamble_id: 'gfci', item: '12/2   ROMEX', cantidad: 0.02 },
    { ensamble_id: 'gfci', item: 'NM CABLE CONNECTOR 1/2"', cantidad: 1 },
    { ensamble_id: 'sec', item: '10/3   ROMEX', cantidad: 0.025 },
    { ensamble_id: 'sec', item: 'NM CABLE CONNECTOR 3/4"', cantidad: 1 }
  ];
  const cort = await p.evaluate(([e, i]) => window.MXP_PRUEBA.e0.conectorCorto(e, i), [ENS, ENSI]);
  ok('encuentra la receta del cargador: 6/3 con un conector NM de ½", por ahí no pasa ese cable', cort.length === 1 && /EV CHARGER/.test(cort[0].receta) && cort[0].cable === 6, JSON.stringify(cort));
  ok('y dice cuál hace falta de verdad para un #6: el de 1", no el de ¾"', /NM CABLE CONNECTOR 1"/.test(cort[0].hace_falta), cort[0].hace_falta);
  ok('…y avisa de que esa pieza NO está en su catálogo, que es justo por lo que llevaba el chico', cort[0].enCatalogo === false, JSON.stringify(cort[0].enCatalogo));
  const cortHay = await p.evaluate(([e, i]) => { window.MXP_PRUEBA.e0.datos({ catalogo: [{ item: 'NM CABLE CONNECTOR 1"', precio: 2.4 }], items: [], config: {}, estimados: [], ensambles: e, ensambleItems: i }); return window.MXP_PRUEBA.e0.conectorCorto(e, i); }, [ENS, ENSI]);
  ok('si la pieza buena SÍ está en el catálogo, lo dice y solo hay que cambiar la receta', cortHay[0].enCatalogo === true, JSON.stringify(cortHay[0].enCatalogo));
  ok('un 12/2 con conector de ½" está bien y no se señala; un 10/3 con el de ¾" tampoco', !cort.some(x => /GFCI|SECADORA/.test(x.receta)), JSON.stringify(cort.map(x => x.receta)));
  const tarjC = await p.evaluate(([e, i, es]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: [], items: [], config: {}, estimados: [], ensambles: e, ensambleItems: i });
    const h = window.MXP_PRUEBA.e0.tarjetas(es, { items: [], autos: [] });
    return { sale: /no le cabe al cable/.test(h), ev: /EV CHARGER/.test(h) };
  }, [ENS, ENSI, EST]);
  ok('sale en el estimador, nombrando la receta y lo que le falta', tarjC.sale && tarjC.ev, JSON.stringify(tarjC));
  await datos();

  /* ===== 14 · lo que sacó la VERIFICACIÓN del 21/09 ===== */
  await datos();
  const estRef = Object.assign({}, EST, { usa_luz_ref: true });
  const cR = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), estRef);
  const tk = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.takeoff(e, c), [estRef, cR]);
  /* (22/09) La línea suelta con el total se quitó: era el MISMO dinero que ya
     traen las filas, y sumaba $19.630 de más leyendo la columna hacia abajo. Lo
     que tiene que estar son las FILAS, con su cantidad y su precio. */
  ok('el TAKEOFF que se pega en Excel lleva las luminarias de referencia como FILAS, con su precio, para poder cuadrarlas',
    /precio de referencia/.test(tk) && !/\+ Luminarias a PRECIO DE REFERENCIA/.test(tk),
    (tk.match(/[^\n]*precio de referencia[^\n]*/) || [''])[0].slice(0, 110));
  ok('…y cada luminaria sale como renglón, con su precio y de qué familia salió', (tk.match(/precio de referencia \(/g) || []).length === 5 && /STAK 2X2 5000LM/.test(tk), (tk.match(/[^\n]*precio de referencia \([^\n]*/) || [''])[0].slice(0, 100));
  const lineasRef = tk.split('\n').filter(x => /precio de referencia \(/.test(x));
  ok('esos renglones llevan el nombre limpio, sin el recordatorio con tu precio ni el «COTIZACIÓN PENDIENTE»', lineasRef.length === 5 && !lineasRef.some(x => /pedir a Jose|COTIZACI[OÓ]N PENDIENTE/.test(x)), (lineasRef[0] || '').replace(/\t+/g, ' | ').slice(0, 120));
  const tkOff = await p.evaluate(([e, c]) => window.MXP_PRUEBA.e0.takeoff(e, c), [EST, await p.evaluate(x => window.MXP_PRUEBA.e0.calcula(x), EST)]);
  ok('con la referencia apagada el takeoff sale como siempre: ni la línea ni los renglones', !/PRECIO DE REFERENCIA/.test(tkOff), '');
  // la clave del selector es la MISMA con que se aprende
  const TIPOA = 'COTIZACIÓN PENDIENTE — LITHONIA BLT 2X4 (TIPO A) MVOLT (ref. $180)';
  const itemsA = ITEMS.map(x => x.id === 'c1' ? Object.assign({}, x, { item: TIPOA }) : x);
  const selCl = await p.evaluate(([i, e, ta]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: [], items: i, config: {}, estimados: [] });
    const c = window.MXP_PRUEBA.e0.calcula(e);
    const d = document.createElement('div'); d.innerHTML = window.MXP_PRUEBA.e0.tarjetas(e, c);
    const sel = [...d.querySelectorAll('select.luz-fam')].map(x => x.dataset.modelo);
    return { sel, claveA: window.MXP_PRUEBA.e0.luzClave(ta) };
  }, [itemsA, Object.assign({}, EST, { usa_luz_ref: true }), TIPOA]);
  ok('el desplegable manda la CLAVE de aprendizaje, no el modelo «bonito»: con un paréntesis descriptivo ya casan', selCl.sel.indexOf(selCl.claveA) >= 0 && /TIPO A/.test(selCl.claveA), JSON.stringify([selCl.claveA, selCl.sel[0]]));
  // un precio flojo no se pinta como resuelto
  const cfgFl = { luz_fam: JSON.stringify({ [await p.evaluate(m => window.MXP_PRUEBA.e0.luzClave(m), RARO)]: 0.5 }) };
  const pintFl = await p.evaluate(([i, e, c]) => {
    window.MXP_PRUEBA.e0.datos({ catalogo: [], items: i, config: c, estimados: [] });
    const est = Object.assign({}, e, { usa_luz_ref: true });
    const d = document.createElement('div'); d.innerHTML = window.MXP_PRUEBA.e0.tarjetas(est, window.MXP_PRUEBA.e0.calcula(est));
    const fila = [...d.querySelectorAll('.mat-item')].find(x => /OR-7/.test(x.textContent)) || { textContent: '', innerHTML: '' };
    return { txt: fila.textContent.replace(/\s+/g, ' '), chip: /recibo-chip por_leer/.test(fila.innerHTML) };
  }, [ITEMS_RARO, EST, cfgFl]);
  ok('un precio de 50 centavos sale como AVISO en su fila, no como precio bueno, y no enseña un total falso', pintFl.chip === true && /no es el precio de una luminaria/.test(pintFl.txt) && !/\$10\.00/.test(pintFl.txt), pintFl.txt.slice(0, 130));
  // enseñar una familia avisa de cuántos estimados más se mueven
  const otros = await p.evaluate(() => { window.MXP_PRUEBA.e0.datos({ catalogo: [], items: [], config: {}, estimados: [{ id: 'a', usa_luz_ref: true }, { id: 'b', usa_luz_ref: true }, { id: 'c' }] }); return window.MXP_PRUEBA.e0.otrosRef(); });
  /* (21/09) DOS FILAS DEL CATÁLOGO CON EL MISMO NOMBRE. Salió de la
     comprobación de Supabase: el «1" EMT S.S. D/C CONNECTOR» estaba dos veces.
     catalogoExacto es un .find y se queda con la primera que llegue, en un
     orden que no está garantizado: mientras valgan lo mismo da igual, pero al
     corregir una con el precio del supply la receta puede seguir cobrando la
     otra, callada. */
  const dbl = await p.evaluate(() => window.MXP_PRUEBA.e0.auditoria([
    { id: 1, item: '1"       EMT S.S. D/C CONNECTOR', precio: 3.2247, horas_unidad: 0.05 },
    { id: 2, item: '1"  EMT  S.S.  D/C  CONNECTOR',   precio: 3.2247, horas_unidad: 0.05 },   // el mismo, con otros espacios
    { id: 3, item: 'CAJA 4X4', precio: 2.10, horas_unidad: 0.1 },
    { id: 4, item: 'caja 4x4', precio: 9.99, horas_unidad: 0.1 },                              // gemela con OTRO precio
    { id: 5, item: 'UNA SOLA', precio: 1, horas_unidad: 0 }
  ]));
  ok('la auditoría caza las filas repetidas del catálogo, aunque solo cambien los espacios',
    dbl.dobles && dbl.dobles.length === 2 && dbl.dobles.every(d => d.n === 2), JSON.stringify(dbl.dobles && dbl.dobles.map(d => [d.item, d.n])));
  ok('y pone DELANTE la que no vale lo mismo, que es la que puede mover el número',
    dbl.dobles[0].difiere === true && dbl.dobles[0].precios.length === 2 && dbl.dobles[1].difiere === false,
    JSON.stringify(dbl.dobles.map(d => [d.item, d.difiere, d.precios])));
  ok('un catálogo sin repetidos no inventa ninguna',
    (await p.evaluate(() => window.MXP_PRUEBA.e0.auditoria([{ id: 1, item: 'A', precio: 1 }, { id: 2, item: 'B', precio: 2 }]).dobles.length)) === 0, '');

  /* (22/09) EL TAKEOFF TIENE QUE CUADRAR HACIA ABAJO. Ayer se arregló el hueco de
     la referencia DOS VECES en el mismo commit: entraron sus filas a la columna Y
     se añadió una línea con el total. Leyendo hacia abajo salvaban $19.630 de
     más en Nicklaus. La prueba de ayer solo miraba que la LÍNEA existiera, no que
     la columna sumara — por eso pasó con el doble conteo dentro. Esta suma. */
  const cuadre = await p.evaluate(([e, c, i, clv]) => {
    const D = window.MXP_PRUEBA.e0;
    const cfg = { luz_fam: JSON.stringify(D.luzAprende({ luz_fam: '{}' }, clv, 250)) };
    D.datos({ catalogo: c, items: i, config: cfg, estimados: [], escenarios: [], ensambleItems: [] });
    const est = Object.assign({}, e, { usa_luz_ref: true });
    const calc = D.calcula(est);
    const txt = D.takeoff(est, calc);
    const lin = txt.split('\n');
    const val = (nom) => { const f = lin.find(l => l.split('\t')[1] === nom); return f ? Number(String(f.split('\t')[7]).trim()) || 0 : null; };
    const suma = ['Material de los renglones', '+ Merma (cable / tubería)', '+ Misceláneas', '+ Sales tax',
                  '+ Luminarias a PRECIO DE REFERENCIA (cuota pendiente)']
      .reduce((a, k) => a + (val(k) || 0), 0);
    D.datos({ catalogo: c, items: i, config: {}, estimados: [], escenarios: [], ensambleItems: [] });
    return { refLuz: calc.refLuz.total, suma: Math.round(suma * 100) / 100, material: val('= MATERIAL'),
             hayFilasRef: lin.filter(l => /precio de referencia/.test(l)).length,
             hayLineaRef: val('+ Luminarias a PRECIO DE REFERENCIA (cuota pendiente)') };
  }, [EST, CAT, ITEMS, ITEMS.find(x => x.id === 'c1').item]);
  ok('el takeoff CUADRA leyendo la columna hacia abajo: renglones + merma + misceláneas + tax = MATERIAL',
    Math.abs(cuadre.suma - cuadre.material) <= 0.02, JSON.stringify([cuadre.suma, cuadre.material, cuadre.refLuz]));
  ok('la referencia sale como FILAS con su cantidad y su precio (que es lo que sirve para cuadrar renglón a renglón), no como un total suelto repetido',
    cuadre.hayFilasRef > 0 && cuadre.hayLineaRef === null, JSON.stringify([cuadre.hayFilasRef, cuadre.hayLineaRef]));
  ok('y la referencia SIGUE dentro del número: el bid no perdió los dólares al quitar la línea repetida',
    cuadre.refLuz > 0 && cuadre.material > cuadre.refLuz, JSON.stringify([cuadre.refLuz, cuadre.material]));

  /* (21/09) ALIAS QUE TAPAN UNA FILA DEL CATÁLOGO. emparejarTakeoff busca por
     código → ALIAS → nombre exacto: el alias va ANTES que el nombre. Salió de
     «CT CABINET» (E · 2 h), que un alias mandaba a «CT/METER CAN» (EA · 3 h),
     y en Bluebeam son dos conteos distintos: tu fila no llega a mirarse. */
  const CATT = [
    { id: 1, item: 'CT CABINET',   unidad: 'E',  precio: 0, horas_unidad: 2 },
    { id: 2, item: 'CT/METER CAN', unidad: 'EA', precio: 0, horas_unidad: 3 },
    { id: 3, item: 'JB 1900 BOX',  unidad: 'E',  precio: 1.04, horas_unidad: 0.25 }
  ];
  const tapan = await p.evaluate(c => window.MXP_PRUEBA.e0.tapan([
    { alias: 'CT CABINET',   item: 'CT/METER CAN', factor: 1 },   // TAPA: se llama como una fila y manda a otra
    { alias: 'CT CABINET',   item: 'CT CABINET',   factor: 1 },   // apunta a su propia fila: inofensivo
    { alias: 'WALL OUTLET',  item: 'JB 1900 BOX',  factor: 1 },   // no tapa nada: no hay fila «WALL OUTLET»
    { alias: 'jb 1900 box',  item: 'INVENTADA',    factor: 1 }    // tapa, y encima manda a algo que no existe
  ], c), CATT);
  ok('caza el alias que se llama como una fila del catálogo y manda a otra pieza, y deja en paz al que apunta a la suya',
    tapan.length === 2 && tapan.some(t => t.alias === 'CT CABINET' && t.item === 'CT/METER CAN'),
    JSON.stringify(tapan.map(t => t.alias + ' → ' + t.item)));
  ok('dice qué fila tuya queda tapada, con sus horas, para ver lo que cambia',
    (tapan.find(t => t.alias === 'CT CABINET') || {}).tapada.horas_unidad === 2 &&
    (tapan.find(t => t.alias === 'CT CABINET') || {}).destino.horas_unidad === 3,
    JSON.stringify(tapan.map(t => [t.alias, t.tapada && t.tapada.horas_unidad, t.destino && t.destino.horas_unidad])));
  ok('y marca el que manda a una pieza que ni siquiera está en el catálogo',
    (tapan.find(t => t.item === 'INVENTADA') || {}).destino === null, '');
  ok('sin alias que tapen, no inventa ninguno',
    (await p.evaluate(c => window.MXP_PRUEBA.e0.tapan([{ alias: 'ALGO', item: 'JB 1900 BOX' }], c).length, CATT)) === 0, '');

  ok('la app sabe cuántos OTROS estimados usan referencia, para decirlo al enseñar una familia', otros === 2, otros);
  await datos();

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 250));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(r => r.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' pasos bien, todo bien'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
