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
  ok('cuenta 31 dimmers/sensores para la puesta en marcha', cu.dimmer === 31, cu.dimmer);
  ok('cuenta 55 luminarias y no confunde con ellas la cotización pendiente', cu.luminaria === 55, cu.luminaria);

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

  /* ===== 5 · el precio de referencia ===== */
  const ref = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i, {}), ITEMS);
  ok('las cinco líneas pendientes llevan referencia, ninguna se queda fuera', ref.filas.length === 5 && ref.sinFamilia.length === 0, JSON.stringify(ref.filas.map(x => [x.familia, x.precio])));
  ok('el total de referencia son $19.630 (25×150 + 23×150 + 20×550 + 3×220 + 7×110)', ref.total === 19630, ref.total);
  const refOv = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i, { luz_ref: '{"cleanroom":610,"troffer22":168}' }), ITEMS);
  ok('los precios que Edgar guarde mandan sobre los de arranque (cleanroom 610, 2x2 168)', refOv.total === 21694, refOv.total);
  const refMal = await p.evaluate(i => window.MXP_PRUEBA.e0.refLuz(i.map(x => x.id === 'c3' ? Object.assign({}, x, { item: 'COTIZACIÓN PENDIENTE — ARTEFACTO RARO XYZ' }) : x), {}), ITEMS);
  ok('una luminaria de familia desconocida no suma nada y se señala', refMal.sinFamilia.length === 1 && refMal.total === 19630 - 11000, JSON.stringify([refMal.sinFamilia.length, refMal.total]));

  /* ===== 6 · el dinero: apagado no mueve nada, encendido entra como cotización ===== */
  const off = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(e), EST);
  const on = await p.evaluate(e => window.MXP_PRUEBA.e0.calcula(Object.assign({}, e, { usa_luz_ref: true })), EST);
  ok('apagado (por defecto) el bid es el de siempre: la referencia no entra', off.refLuz.total === 0 && Math.abs(off.matCot) < 0.01, JSON.stringify([off.refLuz.total, off.matCot]));
  ok('encendido, los $19.630 entran por la puerta de las COTIZACIONES, no como material propio',
    Math.abs(on.matCot - 19630) < 0.01 && Math.abs(on.matPropio - off.matPropio) < 0.01, JSON.stringify([on.matCot, Math.round(on.matPropio), Math.round(off.matPropio)]));
  ok('y por eso no pagan misceláneas: el misc no se mueve', Math.abs(on.misc - off.misc) < 0.01, JSON.stringify([on.misc, off.misc]));
  ok('el bid sube lo que tiene que subir y las horas no cambian', on.bid > off.bid + 19630 && Math.abs(on.horas - off.horas) < 0.01, JSON.stringify([Math.round(off.bid), Math.round(on.bid), on.horas]));

  /* ===== 7 · lo que se ve en el renglón ===== */
  const chipOff = await p.evaluate(([l, e]) => window.MXP_PRUEBA.e0.cero(l, e), [ITEMS[7], EST]);
  const chipOn = await p.evaluate(([l, e]) => window.MXP_PRUEBA.e0.cero(l, Object.assign({}, e, { usa_luz_ref: true })), [ITEMS[7], EST]);
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
             titulos: [...d.querySelectorAll('.cal-form-titulo')].map(x => x.textContent.trim().slice(0, 22)) };
  }, EST);
  ok('las tres tarjetas se pintan sin lanzar', !pint.fallo && pint.largo > 3000, JSON.stringify([pint.fallo, pint.largo, pint.titulos]));
  ok('la tabla de consumibles trae sus 18 números editables', pint.consumibles === 18, pint.consumibles);
  ok('la de horas trae una casilla por regla y la de luz sus 9 familias', pint.horas === 9 && pint.luz === 9, JSON.stringify([pint.horas, pint.luz]));
  const flojo = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetas(e, { items: null, autos: null }), EST);
  ok('un cálculo a medias (sin ítems ni automáticos) no rompe ninguna tarjeta', !/Una tarjeta nueva falló/.test(flojo), flojo.slice(0, 60));
  const rota = await p.evaluate(e => window.MXP_PRUEBA.e0.tarjetas(e, null), EST);
  ok('y si aun así una lanzara, se cae ELLA sola: el estimador sigue en pie', /Una tarjeta nueva falló/.test(rota) && rota.split("Una tarjeta nueva falló").length - 1 >= 1, rota.replace(/\s+/g, ' ').slice(0, 110));

  ok('cero errores de página', errs.length === 0, errs.join(' | ').slice(0, 250));
  console.log('\n' + R.join('\n'));
  const mal = R.filter(r => r.slice(0, 4).indexOf('✗') >= 0).length;
  console.log('\n' + (R.length - mal) + '/' + R.length + (mal ? ' — FALLA' : ' pasos bien, todo bien'));
  await b.close(); srv.close();
  process.exit(mal ? 1 : 0);
})();
